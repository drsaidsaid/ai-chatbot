# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::LeadsDirectoryService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:hidden_whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox.tap { |record| record.update!(name: 'WhatsApp sales') } }
  let(:hidden_inbox) { hidden_whatsapp_channel.inbox.tap { |record| record.update!(name: 'Hidden source') } }

  before do
    create(:inbox_member, user: operator, inbox: inbox)
  end

  describe '#perform' do
    it 'returns unique tenant leads with quality counts, details, and pagination' do
      qualified = create(
        :contact,
        :with_phone_number,
        account: account,
        name: 'Jane Nkosi',
        additional_attributes: { 'company_name' => 'Nuru Boutique', 'city' => 'Arusha', 'country' => 'TZ' },
        last_activity_at: 1.hour.ago
      )
      unknown = create(
        :contact,
        :with_phone_number,
        account: account,
        name: 'Salum Abdalla',
        additional_attributes: { 'company_name' => 'Abdalla Auto Spares' },
        last_activity_at: 2.hours.ago
      )
      conversation = create(:conversation, account: account, inbox: inbox, contact: qualified, assignee: operator, last_activity_at: 30.minutes.ago)
      create(:conversation, account: account, inbox: inbox, contact: unknown, last_activity_at: 2.hours.ago)
      create(:message, account: account, inbox: inbox, conversation: conversation, content: 'Please automate WhatsApp lead capture.')
      qualification = create(
        :lead_qualification,
        account: account,
        contact: qualified,
        quality: :qualified,
        follow_up_state: :nurture,
        score: 78,
        reasons: ['Budget is plausible'],
        missing_signals: ['team_size']
      )
      create(:qualification_evidence, account: account, contact: qualified, conversation: conversation, signal: :problem,
                                      value: { 'value' => 'book demos automatically' })
      create(:lead_follow_up, account: account, contact: qualified, conversation: conversation, lead_qualification: qualification,
                              scheduled_at: 1.day.from_now)

      payload = described_class.new(account: account, user: admin, params: { q: 'automate', per_page: 25 }).perform

      expect(payload[:leads].pluck(:id)).to eq([qualified.id])
      expect(payload[:counts]).to include('all' => 1, 'qualified' => 1, 'unknown' => 0)
      expect(payload[:meta]).to include(page: 1, per_page: 25, total_count: 1)
      expect(payload[:selected_lead]).to include(
        id: qualified.id,
        business_name: 'Nuru Boutique',
        quality: 'qualified',
        score: 78,
        source: hash_including(name: 'WhatsApp sales'),
        assignee: hash_including(id: operator.id),
        location: 'Arusha, TZ'
      )
      expect(payload[:selected_lead].dig(:detail, :strongest_evidence).first).to include(signal: 'problem')
      expect(payload[:selected_lead].dig(:detail, :conversation_summary, :last_message_preview)).to eq('Please automate WhatsApp lead capture.')
    end

    it 'keeps Leads distinct from Inbox queues by including all quality levels and Unknown contacts' do
      highly_qualified = create(:contact, :with_phone_number, account: account, name: 'Hot Lead')
      low_qualified = create(:contact, :with_phone_number, account: account, name: 'Low Lead')
      unknown = create(:contact, :with_phone_number, account: account, name: 'Unknown Lead')
      [highly_qualified, low_qualified, unknown].each do |contact|
        create(:conversation, account: account, inbox: inbox, contact: contact)
      end
      create(:lead_qualification, account: account, contact: highly_qualified, quality: :highly_qualified)
      create(:lead_qualification, account: account, contact: low_qualified, quality: :low_qualified)

      payload = described_class.new(account: account, user: admin, params: {}).perform

      expect(payload[:leads].pluck(:id)).to contain_exactly(highly_qualified.id, low_qualified.id, unknown.id)
      expect(payload[:counts]).to include('all' => 3, 'highly_qualified' => 1, 'low_qualified' => 1, 'unknown' => 1)
    end

    it 'filters by assignee, source, follow-up state, booking status, and selected quality' do
      booked = create(:contact, :with_phone_number, account: account, name: 'Booked Lead')
      unbooked = create(:contact, :with_phone_number, account: account, name: 'Unbooked Lead')
      booked_conversation = create(:conversation, account: account, inbox: inbox, contact: booked, assignee: operator)
      create(:conversation, account: account, inbox: hidden_inbox, contact: unbooked)
      booked_qualification = create(:lead_qualification, account: account, contact: booked, quality: :highly_qualified, follow_up_state: :call_booked)
      create(:lead_qualification, account: account, contact: unbooked, quality: :qualified, follow_up_state: :nurture)
      booking = create(:booking, account: account, contact: booked, conversation: booked_conversation,
                                 lead_qualification: booked_qualification, assignee: operator)

      payload = described_class.new(
        account: account,
        user: admin,
        params: {
          quality: 'highly_qualified',
          follow_up_state: 'call_booked',
          assignee_id: operator.id,
          source_id: inbox.id,
          booking_status: 'booked'
        }
      ).perform

      expect(payload[:leads].pluck(:id)).to eq([booked.id])
      expect(payload[:leads].first.dig(:booking, :status)).to eq('confirmed')
      expect(payload[:leads].first.dig(:detail, :related_bookings).first).to include(
        id: booking.id,
        path: "/app/accounts/#{account.id}/bookings?booking_id=#{booking.id}"
      )
    end

    it 'limits Human Operators to assigned or permitted conversations' do
      permitted = create(:contact, :with_phone_number, account: account)
      assigned = create(:contact, :with_phone_number, account: account)
      hidden = create(:contact, :with_phone_number, account: account)
      create(:conversation, account: account, inbox: inbox, contact: permitted)
      create(:conversation, account: account, inbox: hidden_inbox, contact: assigned, assignee: operator)
      create(:conversation, account: account, inbox: hidden_inbox, contact: hidden)
      [permitted, assigned, hidden].each { |contact| create(:lead_qualification, account: account, contact: contact, quality: :qualified) }

      payload = described_class.new(account: account, user: operator, params: {}).perform

      expect(payload[:leads].pluck(:id)).to contain_exactly(permitted.id, assigned.id)
      expect(payload[:meta][:visibility]).to eq('operator')
    end

    it 'paginates more than 100 leads with stable metadata' do
      101.times do |index|
        contact = create(:contact, :with_phone_number, account: account, name: "Lead #{index.to_s.rjust(3, '0')}",
                                                       last_activity_at: index.minutes.ago)
        create(:conversation, account: account, inbox: inbox, contact: contact, last_activity_at: index.minutes.ago)
        create(:lead_qualification, account: account, contact: contact, quality: :qualified)
      end

      payload = described_class.new(account: account, user: admin, params: { page: 2, per_page: 25 }).perform

      expect(payload[:leads].size).to eq(25)
      expect(payload[:meta]).to include(page: 2, per_page: 25, total_count: 101, total_pages: 5)
    end
  end
end

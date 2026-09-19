# frozen_string_literal: true

require 'rails_helper'

# The small provider fake and eager connection are shared contract fixtures for this service.
# rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration, RSpec/LetSetup

RSpec.describe AiLeadEmployee::BookingProposalService do
  class ProposalCalendarFake
    def free_busy(**)
      AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(busy_slots: [], state: 'connected', error_code: nil)
    end
  end

  let(:account) do
    create(:account, settings: { 'ai_lead_employee' => { 'booking' => {
             'timezone' => 'Africa/Dar_es_Salaam', 'working_days' => [1],
             'allowed_hours' => { 'start' => '09:00', 'end' => '10:00' },
             'duration_minutes' => 30, 'minimum_notice_minutes' => 60
           } } })
  end
  let!(:connection) do
    create(:google_calendar_connection, account: account, status: :connected, access_token: nil, refresh_token: nil)
  end
  let(:user) { create(:user, account: account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, contact: contact, offer: offer, assignee: user) }
  let(:offer) do
    AiLeadEmployee::Offer.create!(
      account: account, name: 'Free fit call', currency: 'TZS', enabled: true, configuration_version: 1,
      configuration: {
        'qualification_mode' => 'disabled', 'next_step' => { 'kind' => 'sales_call' },
        'questions' => [], 'rules' => [], 'score_weights' => {},
        'score_thresholds' => { 'qualified' => 0, 'highly_qualified' => 100 }
      }
    )
  end
  let(:starts_at) { Time.zone.parse('2026-08-31T06:00:00Z') }

  before { allow(Chatwoot).to receive(:encryption_configured?).and_return(true) }

  it 'offers one provider-backed time idempotently and binds the Lead yes reply to that exact timestamp' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      service = described_class.new(conversation: conversation, qualification: nil, user: user, starts_at: starts_at,
                                    idempotency_key: 'proposal-one', calendar_client: ProposalCalendarFake.new)
      message = service.perform
      duplicate = service.perform

      expect(duplicate.id).to eq(message.id)
      expect(message.content).to include('Monday, August 31 at 9:00 AM EAT')
      expect(message.additional_attributes.dig('ai_lead_employee', 'booking_proposal')).to include(
        'starts_at' => starts_at.iso8601, 'offer_id' => offer.id, 'offer_configuration_version' => 1
      )
      expect(conversation.messages.outgoing.count).to eq(1)

      reply = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                               message_type: :incoming, content: 'Yes')
      evidence = AiLeadEmployee::OfferEvidenceRecorder.new(
        conversation: conversation, offer: offer, incoming_message: reply
      ).perform.sole
      expect(evidence).to have_attributes(field_key: 'sales_call_agreement', message: reply)
      expect(evidence.value).to include('typed_value' => true, 'proposal_message_id' => message.id,
                                        'agreed_starts_at' => starts_at.iso8601)
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, RSpec/LeakyConstantDeclaration, RSpec/LetSetup

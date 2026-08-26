# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OperationalDashboardService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:hidden_inbox) { create(:inbox, account: account) }

  before do
    create(:inbox_member, user: operator, inbox: inbox)
  end

  describe '#perform' do
    it 'returns lead rows with qualification, ownership, source, booking, and rebuild fields' do
      contact = create(:contact, :with_email, :with_phone_number, account: account, name: 'Asha Mushi')
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact, assignee: operator, control_state: :human_active)
      create(:lead_qualification,
             account: account,
             contact: contact,
             quality: :highly_qualified,
             follow_up_state: :call_booked,
             score: 91,
             reasons: ['Has budget', 'Needs help this week'])
      create(:lead_handoff, account: account, contact: contact, conversation: conversation, assignee: operator,
                            lead_qualification: contact.lead_qualification)

      payload = described_class.new(account: account, user: admin, filters: {}).perform
      row = payload[:leads].first

      expect(row).to include(
        id: contact.id,
        name: 'Asha Mushi',
        email: contact.email,
        phone_number: contact.phone_number,
        quality: 'highly_qualified',
        follow_up_state: 'call_booked',
        score: 91,
        assignee: hash_including(id: operator.id, name: operator.name),
        source: hash_including(id: inbox.id, name: inbox.name),
        booking_state: 'booked',
        control_state: 'human_active',
        conversation_display_id: conversation.display_id
      )
      expect(row[:reasons]).to eq(['Has budget', 'Needs help this week'])
      expect(row[:authoritative_labels]).to include('ai-quality-highly-qualified', 'ai-follow-up-call-booked', 'ai-booked')
      expect(row[:authoritative_custom_attributes]).to include(
        lead_quality: 'highly_qualified',
        follow_up_state: 'call_booked',
        booking_state: 'booked'
      )
    end

    it 'limits Human Operators to assigned or permitted conversations' do
      visible_contact = create(:contact, account: account)
      hidden_contact = create(:contact, account: account)
      assigned_contact = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox, contact: visible_contact)
      create(:conversation, account: account, inbox: hidden_inbox, contact: hidden_contact)
      create(:conversation, account: account, inbox: hidden_inbox, contact: assigned_contact, assignee: operator)
      create(:lead_qualification, account: account, contact: visible_contact, quality: :qualified)
      create(:lead_qualification, account: account, contact: hidden_contact, quality: :highly_qualified)
      create(:lead_qualification, account: account, contact: assigned_contact, quality: :low_qualified)

      payload = described_class.new(account: account, user: operator, filters: {}).perform

      expect(payload[:leads].pluck(:id)).to contain_exactly(visible_contact.id, assigned_contact.id)
      expect(payload[:visibility]).to eq(:operator)
    end

    it 'applies queue filters for quality, follow-up state, assignee, source, unanswered questions, and booking status' do
      booked_contact = create(:contact, account: account)
      review_contact = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox, contact: booked_contact, assignee: operator)
      review_conversation = create(:conversation, account: account, inbox: inbox, contact: review_contact)
      create(:lead_qualification, account: account, contact: booked_contact, quality: :highly_qualified, follow_up_state: :call_booked)
      create(:lead_qualification, account: account, contact: review_contact, quality: :qualified, follow_up_state: :human_review)
      lead_message = create(:message, account: account, conversation: review_conversation, inbox: inbox)
      create(:human_review_request, account: account, conversation: review_conversation, lead_message: lead_message)

      payload = described_class.new(
        account: account,
        user: admin,
        filters: {
          quality: 'qualified',
          follow_up_state: 'human_review',
          assignee_id: 'unassigned',
          source_id: inbox.id.to_s,
          unanswered: 'true',
          booking_status: 'not_booked'
        }
      ).perform

      expect(payload[:leads].pluck(:id)).to eq([review_contact.id])
    end

    it 'applies the knowledge approval queue filter from open review requests' do
      unanswered_contact = create(:contact, account: account)
      knowledge_contact = create(:contact, account: account)
      unanswered_conversation = create(:conversation, account: account, inbox: inbox, contact: unanswered_contact)
      knowledge_conversation = create(:conversation, account: account, inbox: inbox, contact: knowledge_contact)
      unanswered_message = create(:message, account: account, conversation: unanswered_conversation, inbox: inbox)
      knowledge_message = create(:message, account: account, conversation: knowledge_conversation, inbox: inbox)
      knowledge_item = create(:knowledge_item, account: account, status: :draft)
      create(:human_review_request, account: account, conversation: unanswered_conversation, lead_message: unanswered_message)
      create(
        :human_review_request,
        account: account,
        conversation: knowledge_conversation,
        lead_message: knowledge_message,
        knowledge_item: knowledge_item
      )
      create(:lead_qualification, account: account, contact: unanswered_contact, quality: :qualified)
      create(:lead_qualification, account: account, contact: knowledge_contact, quality: :qualified)

      payload = described_class.new(
        account: account,
        user: admin,
        filters: { knowledge_approval: 'true' }
      ).perform

      expect(payload[:leads].pluck(:id)).to eq([knowledge_contact.id])
    end

    it 'returns basic performance metrics from the visible tenant scope' do
      highly_qualified = create(:contact, account: account)
      booked = create(:contact, account: account)
      create(:conversation, account: account, inbox: inbox, contact: highly_qualified)
      create(:conversation, account: account, inbox: inbox, contact: booked)
      create(:lead_qualification, account: account, contact: highly_qualified, quality: :highly_qualified)
      create(:lead_qualification, account: account, contact: booked, quality: :qualified, follow_up_state: :call_booked)
      create(:knowledge_item, account: account, status: :draft)

      payload = described_class.new(account: account, user: operator, filters: {}).perform

      expect(payload[:performance]).to include(
        total_leads: 2,
        highly_qualified_leads: 1,
        booked_calls: 1,
        knowledge_approvals: 1
      )
    end
  end
end

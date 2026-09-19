# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::BookingEligibility do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:offer) do
    AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Free fit call',
      currency: 'TZS',
      enabled: true,
      configuration_version: 1,
      configuration: {
        'qualification_mode' => 'enabled',
        'next_step' => { 'kind' => 'sales_call' },
        'questions' => [],
        'rules' => [],
        'score_weights' => {},
        'score_thresholds' => { 'qualified' => 0, 'highly_qualified' => 100 }
      }
    )
  end
  let(:conversation) { create(:conversation, account: account, contact: contact, offer: offer) }
  let(:agreed_starts_at) { 3.days.from_now }
  let!(:proposal_message) do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :outgoing, content: 'Would this time work?',
                     additional_attributes: {
                       ai_lead_employee: { booking_proposal: {
                         idempotency_key: 'proposal', starts_at: agreed_starts_at.iso8601,
                         ends_at: (agreed_starts_at + 30.minutes).iso8601, offer_id: offer.id,
                         offer_configuration_version: offer.configuration_version
                       } }
                     })
  end
  let(:agreement_message) do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, sender: contact,
                     message_type: :incoming, content: 'Yes')
  end
  let(:qualification) do
    create(
      :lead_qualification,
      account: account,
      contact: contact,
      offer: offer,
      quality: :qualified,
      assessment: {
        'fit' => { 'status' => 'met' },
        'readiness' => { 'status' => 'met' },
        'action_eligibility' => { 'status' => 'met' }
      }
    )
  end

  it 'allows a selected Offer when fit and readiness are met and the Lead explicitly agreed to its sales call' do
    agreement = create(
      :qualification_evidence,
      account: account,
      contact: contact,
      conversation: conversation,
      offer: offer,
      message: agreement_message,
      field_key: 'sales_call_agreement',
      value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
               'agreed_starts_at' => agreed_starts_at.iso8601, 'proposal_message_id' => proposal_message.id,
               'offer_configuration_version' => offer.configuration_version }
    )

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result).to have_attributes(eligible?: true, offer: offer, agreement_evidence: agreement)
  end

  it 'does not substitute global Highly Qualified state for the selected Offer agreement' do
    qualification.update!(quality: :highly_qualified)

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result).to have_attributes(eligible?: false, failure_code: 'lead_agreement_required')
  end

  it 'rejects an agreement that is not the immediate reply to its recorded proposal' do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :outgoing, content: 'A later unrelated question')
    create(
      :qualification_evidence,
      account: account,
      contact: contact,
      conversation: conversation,
      offer: offer,
      message: agreement_message,
      field_key: 'sales_call_agreement',
      value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
               'agreed_starts_at' => agreed_starts_at.iso8601, 'proposal_message_id' => proposal_message.id,
               'offer_configuration_version' => offer.configuration_version }
    )

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result).to have_attributes(eligible?: false, failure_code: 'lead_agreement_required')
  end

  it 'exposes an unmet payment prerequisite for R28 without implementing payment verification' do
    offer.update!(configuration: offer.configuration.deep_merge(
      'next_step' => { 'kind' => 'appointment', 'agreement_field' => 'appointment_agreement',
                       'prerequisite' => 'payment_confirmation' }
    ))
    create(
      :qualification_evidence,
      account: account,
      contact: contact,
      conversation: conversation,
      offer: offer,
      message: agreement_message,
      field_key: 'appointment_agreement',
      value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
               'agreed_starts_at' => agreed_starts_at.iso8601, 'proposal_message_id' => proposal_message.id,
               'offer_configuration_version' => offer.configuration_version }
    )

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result).to have_attributes(eligible?: false, failure_code: 'payment_confirmation_required')
    expect(result.prerequisite_snapshot).to include('kind' => 'payment_confirmation', 'status' => 'required')
  end

  it 'allows a free appointment path with its own explicit agreement field' do
    offer.update!(configuration: offer.configuration.deep_merge(
      'qualification_mode' => 'disabled',
      'next_step' => { 'kind' => 'appointment', 'agreement_field' => 'appointment_agreement' }
    ))
    agreement = create(
      :qualification_evidence,
      account: account,
      contact: contact,
      conversation: conversation,
      offer: offer,
      message: agreement_message,
      field_key: 'appointment_agreement',
      value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
               'agreed_starts_at' => agreed_starts_at.iso8601, 'proposal_message_id' => proposal_message.id,
               'offer_configuration_version' => offer.configuration_version }
    )

    result = described_class.new(conversation: conversation, qualification: nil).perform

    expect(result).to have_attributes(eligible?: true, agreement_evidence: agreement)
  end

  it 'rejects agreement evidence captured for an older Offer revision' do
    create(
      :qualification_evidence,
      account: account,
      contact: contact,
      conversation: conversation,
      offer: offer,
      message: agreement_message,
      field_key: 'sales_call_agreement',
      value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
               'agreed_starts_at' => agreed_starts_at.iso8601, 'proposal_message_id' => proposal_message.id,
               'offer_configuration_version' => offer.configuration_version - 1 }
    )

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result).to have_attributes(eligible?: false, failure_code: 'lead_agreement_required')
  end
end

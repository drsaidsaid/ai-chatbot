# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::ConversationCockpit::NextActionPayload do
  let(:conversation) do
    instance_double(Conversation, closed?: false, ai_paused?: false, human_active?: false, handoff_requested?: false)
  end
  let(:context) do
    instance_double(
      AiLeadEmployee::ConversationCockpit::Context,
      conversation: conversation,
      open_reviews: [],
      latest_booking: nil,
      unresolved_booking: nil,
      qualification: nil,
      booking_eligibility: nil,
      booking_proposal_eligibility: nil,
      opted_out?: false
    )
  end

  it 'prioritizes an open Review Request over a confirmed Booking' do
    review = instance_double(HumanReviewRequest, question: 'Can we send this price?')
    booking = instance_double(Booking, confirmed?: true, provider_state: 'confirmed')
    allow(context).to receive_messages(open_reviews: [review], latest_booking: booking)

    expect(described_class.new(context).to_h).to include(
      kind: 'answer_review', label: 'Answer review request', detail: review.question
    )
  end

  it 'presents a confirmed Booking as information rather than a confirmation action' do
    booking = instance_double(Booking, confirmed?: true, provider_state: 'confirmed')
    allow(context).to receive_messages(
      latest_booking: booking,
      booking_time_label: 'Sep 15, 2026 at 2:00 PM Africa/Dar_es_Salaam'
    )

    expect(described_class.new(context).to_h).to include(
      kind: 'booking_confirmed', label: 'Call booked'
    )
  end

  it 'does not recommend a canceled or completed Booking as a current booking' do
    historical_booking = instance_double(Booking, confirmed?: false)
    allow(context).to receive(:latest_booking).and_return(historical_booking)

    expect(described_class.new(context).to_h).to include(kind: 'monitor_ai')
  end

  it 'does not present a provider-unknown mutation as a confirmed booking' do
    uncertain_booking = instance_double(Booking, id: 27, confirmed?: true, provider_state: 'unknown')
    allow(context).to receive(:unresolved_booking).and_return(uncertain_booking)

    expect(described_class.new(context).to_h).to include(
      kind: 'reconcile_booking', booking_id: 27, label: 'Reconcile calendar result'
    )
  end

  it 'does not recommend AI continuation after an explicit opt-out' do
    allow(context).to receive(:opted_out?).and_return(true)

    expect(described_class.new(context).to_h).to include(
      kind: 'respect_opt_out', label: 'Automated contact stopped'
    )
  end

  it 'offers only the exact time attached to the Lead agreement evidence' do
    evidence = instance_double(QualificationEvidence, message_id: 42,
                                                      value: { 'agreed_starts_at' => '2026-09-21T06:00:00Z' })
    offer = instance_double(AiLeadEmployee::Offer, id: 7, name: 'Free fit call')
    eligibility = AiLeadEmployee::BookingEligibility::Result.new(
      eligible: true, failure_code: nil, offer: offer, agreement_evidence: evidence, prerequisite_snapshot: {}
    )
    allow(context).to receive(:booking_eligibility).and_return(eligibility)

    expect(described_class.new(context).to_h).to include(
      kind: 'book_call', agreement_message_id: 42, agreed_starts_at: '2026-09-21T06:00:00Z', offer_id: 7
    )
  end

  it 'keeps an open Review Request actionable after an explicit opt-out' do
    review = instance_double(HumanReviewRequest, question: 'Can a human answer this?')
    allow(context).to receive_messages(open_reviews: [review], opted_out?: true)

    expect(described_class.new(context).to_h).to include(
      kind: 'answer_review', label: 'Answer review request', detail: review.question
    )
  end
end

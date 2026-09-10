# frozen_string_literal: true

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
      qualification: nil
    )
  end

  it 'prioritizes an open Review Request over a confirmed Booking' do
    review = instance_double(HumanReviewRequest, question: 'Can we send this price?')
    booking = instance_double(Booking, confirmed?: true)
    allow(context).to receive_messages(open_reviews: [review], latest_booking: booking)

    expect(described_class.new(context).to_h).to include(
      kind: 'answer_review', label: 'Answer review request', detail: review.question
    )
  end

  it 'presents a confirmed Booking as information rather than a confirmation action' do
    booking = instance_double(Booking, confirmed?: true)
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
end

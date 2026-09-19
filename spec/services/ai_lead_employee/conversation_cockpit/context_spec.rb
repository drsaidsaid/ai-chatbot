# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::ConversationCockpit::Context do
  describe '#booking_time_label' do
    it 'formats the instant in the booking timezone' do
      booking = instance_double(Booking, starts_at: Time.utc(2030, 1, 8, 10), timezone: 'Africa/Dar_es_Salaam')
      context = described_class.new(conversation: instance_double(Conversation))

      expect(context.booking_time_label(booking)).to eq('Jan 8, 2030 at 1:00 PM Africa/Dar_es_Salaam')
    end
  end
end

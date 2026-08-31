# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::FollowUpDeliveryJob do
  it 'reconciles due pending follow-ups when invoked without an id' do
    due = create(:lead_follow_up, scheduled_at: 1.minute.ago)
    create(:lead_follow_up, scheduled_at: 1.hour.from_now)
    allow(AiLeadEmployee::FollowUpDeliveryService).to receive(:new).and_call_original
    service = instance_double(AiLeadEmployee::FollowUpDeliveryService, perform: nil)
    allow(AiLeadEmployee::FollowUpDeliveryService).to receive(:new).with(follow_up: due).and_return(service)

    described_class.perform_now

    expect(service).to have_received(:perform).once
  end
end

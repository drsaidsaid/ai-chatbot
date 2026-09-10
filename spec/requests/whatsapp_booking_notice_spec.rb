require 'rails_helper'

RSpec.describe 'Canonical WhatsApp booking mutation notices', type: :request do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:admin) { create(:user, :administrator, account: channel.account) }
  let(:conversation) { create(:conversation, account: channel.account, inbox: channel.inbox, assignee: admin, control_state: :human_active) }
  let(:booking) { create(:booking, account: channel.account, conversation: conversation, contact: conversation.contact, assignee: admin) }
  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  before do
    create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                     message_type: :incoming, provider_created_at: Time.current)
  end

  def mutate_booking(action)
    path = "/api/v1/accounts/#{channel.account_id}/bookings/#{booking.id}/#{action}"
    params = { idempotency_key: "#{action}-once", reason: 'Lead requested a change', starts_at: 3.days.from_now.iso8601 }
    if action == 'cancel'
      post(path, headers: admin.create_new_auth_token,
                 params: params)
    else
      patch(path, headers: admin.create_new_auth_token, params: params)
    end
    expect(response).to have_http_status(:ok)
  end

  %w[cancel reschedule].each do |action|
    it "persists one operator-authorized #{action} notice and recovers it without sending twice" do # rubocop:disable RSpec/MultipleExpectations
      request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.BOOKING.NOTICE"}]}',
                                                            headers: { 'Content-Type' => 'application/json' })
      2.times { mutate_booking(action) }
      expect(request).not_to have_been_requested
      notice = conversation.messages.outgoing.sole
      expect(notice.sender).to eq(admin)
      expect(notice.whatsapp_outbound_delivery).to be_pending
      expect(booking.reload.confirmation_message_id).to eq(notice.id.to_s)
      expect(booking.calendar_event_payload.dig('mutations', "#{action}-once", 'message_id')).to eq(notice.id)
      clear_enqueued_jobs # Simulate losing all enqueue operations after the committed mutation.

      2.times { perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now } }
      mutate_booking(action)
      expect(conversation.messages.outgoing.count).to eq(1)
      expect(notice.reload.source_id).to eq('wamid.BOOKING.NOTICE')
      expect(booking.reload.confirmation_message_id).to eq(notice.id.to_s)
      expect(request).to have_been_requested.once
    end
  end
  { 400 => 'failed', 503 => 'unknown' }.each do |code, state|
    it "retains a #{state} booking notice without treating a duplicate mutation as a retry" do
      request = stub_request(:post, provider_url).to_return(status: code, body: '{"error":{"code":100}}',
                                                            headers: { 'Content-Type' => 'application/json' })
      mutate_booking('cancel')
      notice = conversation.messages.outgoing.sole
      SendReplyJob.perform_now(notice.id)
      mutate_booking('cancel')
      perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
      expect(notice.reload.whatsapp_outbound_delivery.state).to eq(state)
      expect(notice.source_id).to be_nil
      expect(booking.reload.confirmation_message_id).to eq(notice.id.to_s)
      expect(request).to have_been_requested.once
      expect(HumanReviewRequest.where(lead_message: notice, reason: :delivery_unknown).count).to eq(state == 'unknown' ? 1 : 0)
    end
  end

  it 'rechecks the initiating operator membership when a booking notice reaches dispatch' do
    mutate_booking('reschedule')
    notice = conversation.messages.outgoing.sole
    AccountUser.find_by!(account: channel.account, user: admin).destroy!
    request = stub_request(:post, provider_url)
    SendReplyJob.perform_now(notice.id)
    expect(notice.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'sender_access_revoked')
    expect(request).not_to have_been_requested
  end
end

require 'rails_helper'

RSpec.describe RoomChannel do
  let!(:contact_inbox) { create(:contact_inbox) }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  it 'retains the contact-specific widget stream' do
    stub_connection authenticated_user: nil
    subscribe(pubsub_token: contact_inbox.pubsub_token)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(contact_inbox.pubsub_token)
  end

  it 'requires a live dashboard session and never subscribes to the account-wide content stream' do
    stub_connection authenticated_user: user
    subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(user.pubsub_token)
    expect(subscription).not_to have_stream_for("account_#{account.id}")
  end

  it 'rejects a copied pubsub token without a live CE session' do
    stub_connection authenticated_user: nil
    subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
    expect(subscription).to be_rejected
  end

  it 'rejects revoked business membership even when the CE session remains valid' do
    user.account_users.find_by!(account: account).destroy!
    stub_connection authenticated_user: user
    subscribe(user_id: user.id, pubsub_token: user.pubsub_token, account_id: account.id)
    expect(subscription).to be_rejected
  end
end

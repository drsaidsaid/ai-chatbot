require 'rails_helper'

RSpec.describe 'Retained CE action access', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}" }

  it 'rejects a member merge before transferring an inaccessible Lead or deleting either identity' do
    assigned = create(:conversation, account: account, assignee: member)
    hidden = create(:conversation, account: account, assignee: colleague)
    hidden.contact.update!(custom_attributes: { 'secret' => 'Hidden Lead detail' })
    post "#{base}/actions/contact_merge", headers: member.create_new_auth_token,
                                          params: { base_contact_id: assigned.contact_id, mergee_contact_id: hidden.contact_id }, as: :json
    expect(response).to have_http_status(:unauthorized)

    get "#{base}/contacts/#{assigned.contact_id}", headers: member.create_new_auth_token
    expect(response.body).not_to include('Hidden Lead detail')
    get "#{base}/contacts/#{hidden.contact_id}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Hidden Lead detail')
  end

  it 'allows an Admin merge within the Business Account and rejects a foreign merge target' do
    contact = create(:contact, account: account)
    mergee = create(:contact, account: account, custom_attributes: { 'merged' => 'Admin-approved detail' })
    foreign = create(:contact, account: create(:account))
    headers = admin.create_new_auth_token
    post "#{base}/actions/contact_merge", headers: headers,
                                          params: { base_contact_id: contact.id, mergee_contact_id: foreign.id }, as: :json
    expect(response).to have_http_status(:not_found)
    post "#{base}/actions/contact_merge", headers: headers,
                                          params: { base_contact_id: contact.id, mergee_contact_id: mergee.id }, as: :json
    expect(response).to have_http_status(:ok)
    get "#{base}/contacts/#{contact.id}", headers: headers
    expect(response.body).to include('Admin-approved detail')
    get "#{base}/contacts/#{mergee.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end

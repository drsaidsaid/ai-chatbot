require 'rails_helper'

RSpec.describe 'Queued Lead bulk access', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}" }

  def enqueue_labels(user, ids, operation, labels)
    post "#{base}/bulk_actions", headers: user.create_new_auth_token,
                                 params: { type: 'Contact', ids: ids, labels: { operation => labels } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(enqueued_jobs.any? { |job| job[:job] == Contacts::BulkActionJob }).to be(true)
  end

  def labels_for(contact)
    get "#{base}/contacts/#{contact.id}/labels", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    response.parsed_body['payload']
  end

  it 'adds and removes labels only on current assignments, including reassignment while queued' do
    assigned = create(:conversation, account: account, assignee: member)
    reassigned = create(:conversation, account: account, assignee: member)
    hidden = create(:conversation, account: account, assignee: colleague)
    foreign = create(:contact, account: create(:account))
    ids = [assigned.contact_id, reassigned.contact_id, hidden.contact_id, foreign.id]
    enqueue_labels(member, ids, :add, ['r06-label'])
    reassigned.update!(assignee: colleague)
    perform_enqueued_jobs(only: Contacts::BulkActionJob)

    expect(labels_for(assigned.contact)).to eq(['r06-label'])
    expect(labels_for(reassigned.contact)).to be_empty
    expect(labels_for(hidden.contact)).to be_empty
    expect(foreign.reload.label_list).to be_empty

    enqueue_labels(admin, ids, :add, ['r06-label'])
    perform_enqueued_jobs(only: Contacts::BulkActionJob)
    enqueue_labels(member, ids, :remove, ['r06-label'])
    perform_enqueued_jobs(only: Contacts::BulkActionJob)
    expect(labels_for(assigned.contact)).to be_empty
    expect(labels_for(reassigned.contact)).to eq(['r06-label'])
    expect(labels_for(hidden.contact)).to eq(['r06-label'])
  end

  [:demotion, :revocation].each do |change|
    it "cancels Admin deletion after membership #{change} while queued" do
      assigned = create(:conversation, account: account, assignee: admin)
      post "#{base}/bulk_actions", headers: admin.create_new_auth_token,
                                   params: { type: 'Contact', ids: [assigned.contact_id], action_name: 'delete' }, as: :json
      expect(response).to have_http_status(:ok)
      membership = account.account_users.find_by!(user: admin)
      change == :demotion ? membership.update!(role: :agent) : membership.destroy!
      perform_enqueued_jobs(only: Contacts::BulkActionJob)

      other_admin = create(:user, account: account, role: :administrator)
      get "#{base}/contacts/#{assigned.contact_id}", headers: other_admin.create_new_auth_token
      expect(response).to have_http_status(:ok)
    end
  end

  [:add, :remove].each do |operation|
    it "cancels queued label #{operation} after membership revocation" do
      assigned = create(:conversation, account: account, assignee: member)
      assigned.contact.update!(label_list: ['original'])
      enqueue_labels(member, [assigned.contact_id], operation, %w[original new-label])
      account.account_users.find_by!(user: member).destroy!
      perform_enqueued_jobs(only: Contacts::BulkActionJob)
      expect(labels_for(assigned.contact)).to eq(['original'])
    end
  end

  it 'rejects member deletion at HTTP and lets a current Admin delete only within the Business Account' do
    contact = create(:conversation, account: account, assignee: member).contact
    foreign = create(:contact, account: create(:account))
    params = { type: 'Contact', ids: [contact.id, foreign.id], action_name: 'delete' }
    post "#{base}/bulk_actions", headers: member.create_new_auth_token, params: params, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(enqueued_jobs.none? { |job| job[:job] == Contacts::BulkActionJob }).to be(true)

    post "#{base}/bulk_actions", headers: admin.create_new_auth_token, params: params, as: :json
    expect(response).to have_http_status(:ok)
    perform_enqueued_jobs(only: Contacts::BulkActionJob)
    get "#{base}/contacts/#{contact.id}", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:not_found)
    expect(Contact.exists?(foreign.id)).to be(true)
  end
end

require 'rails_helper'

RSpec.describe 'V1 macro HTTP availability', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}" }

  it 'requires authentication before resolving the Business Account' do
    get "#{base}/macros"
    expect(response).to have_http_status(:unauthorized)
  end

  it 'makes every unsupported macro HTTP endpoint unavailable to Admins and Team Members' do
    macro = create(:macro, account: account, created_by: member, updated_by: member, visibility: :personal)
    [admin, member].each do |user|
      headers = user.create_new_auth_token
      [[:get, '/macros'], [:get, "/macros/#{macro.id}"], [:post, '/macros'],
       [:patch, "/macros/#{macro.id}"], [:delete, "/macros/#{macro.id}"], [:post, "/macros/#{macro.id}/execute"]].each do |method, path|
        public_send(method, "#{base}#{path}", headers: headers,
                                              params: { name: 'Unsupported macro', actions: [], conversation_ids: [1] }, as: :json)
        expect(response).to have_http_status(:not_found), "#{user.id} #{method} #{path}"
      end
    end
    expect(enqueued_jobs.none? { |job| job[:job] == MacrosExecutionJob }).to be(true)
  end
end

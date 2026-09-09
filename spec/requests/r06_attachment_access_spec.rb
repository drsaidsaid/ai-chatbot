require 'rails_helper'

RSpec.describe 'Assigned attachment downloads', type: :request do
  let(:account) { create(:account) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: member) }
  let(:message) { create(:message, account: account, conversation: conversation) }
  let(:attachment) do
    Attachment.create!(account: account, message: message, file_type: :file).tap do |record|
      record.file.attach(io: StringIO.new('Restricted Lead document'), filename: 'lead.txt', content_type: 'text/plain')
    end
  end

  def path(url)
    URI.parse(url).request_uri
  end

  it 'requires a valid CE session for both current and legacy attachment URLs, and rechecks assignment' do # rubocop:disable RSpec/MultipleExpectations
    url = attachment.file_url
    legacy = Rails.application.routes.url_helpers.rails_storage_redirect_path(attachment.file)
    ActiveStorage::Current.url_options = { host: 'http://www.example.com' }
    disk = path(attachment.file.blob.url)
    get disk
    expect(response).to have_http_status(:forbidden)
    get path(url)
    expect(response.status).to be_in([401, 403])
    get legacy
    expect(response.status).to be_in([401, 403])

    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: member.create_new_auth_token
    expect(response).to have_http_status(:ok)
    get path(url)
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq('Restricted Lead document')
    expect(response.headers['Cache-Control']).to include('no-store')
    get disk
    expect(response.body).to eq('Restricted Lead document')

    conversation.update!(assignee: colleague)
    get path(url)
    expect(response.status).to be_in([401, 403])
    get legacy
    expect(response.status).to be_in([401, 403])
    get disk
    expect(response).to have_http_status(:forbidden)
  end

  it 'gives the WhatsApp sender a separate expiring capability for only its public outgoing attachment' do
    stub_request(:get, %r{https://graph.facebook.com/}).to_return(status: 200, body: '{"data":[]}', headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, %r{https://graph.facebook.com/.*/phone_numbers}).to_return(status: 200, body: '{"data":[{"id":"123456789"}]}',
                                                                                  headers: { 'Content-Type' => 'application/json' })
    channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud')
    conversation.inbox.update!(channel: channel)
    message.update!(message_type: :outgoing, private: false, sender: member)
    url = attachment.download_url
    get path(url)
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq('Restricted Lead document')
    expect(attachment.file_url).not_to eq(url)
    travel 6.minutes do
      get path(url)
      expect(response.status).to be_in([401, 403, 404])
    end
    message.update!(private: true)
    get path(url)
    expect(response.status).to be_in([401, 403, 404])
  end

  it 'rejects stale media sessions after CE sign-out and does not allow uploads into another assignment' do
    headers = member.create_new_auth_token
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: headers
    url = attachment.file_url
    get path(url)
    expect(response).to have_http_status(:ok)
    delete '/auth/sign_out', headers: headers
    get path(url)
    expect(response.status).to be_in([401, 403])

    conversation.update!(assignee: colleague)
    post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/direct_uploads",
         headers: member.create_new_auth_token,
         params: { blob: { filename: 'test.txt', byte_size: 4, checksum: Digest::MD5.base64digest('test'), content_type: 'text/plain' } }, as: :json
    expect(response.status).to be_in([401, 403, 404])
  end

  it 'rejects replaying a signed attachment into an accessible conversation after losing its source' do
    signed_id = attachment.file.signed_id
    conversation.update!(assignee: colleague)
    own = create(:conversation, account: account, assignee: member)
    expect do
      post "/api/v1/accounts/#{account.id}/conversations/#{own.display_id}/messages",
           headers: member.create_new_auth_token,
           params: { content: 'Replayed file', attachments: [signed_id] }, as: :json
    end.not_to change(Attachment, :count)
    expect(response.status).to be_in([401, 403, 404])
  end

  it 'applies the assignment boundary to image thumbnails and legacy representations' do
    attachment.update!(file_type: :image)
    attachment.file.attach(io: Rails.root.join('spec/assets/sample.png').open, filename: 'sample.png', content_type: 'image/png')
    thumbnail = attachment.thumb_url
    legacy = Rails.application.routes.url_helpers.rails_storage_redirect_path(attachment.file.variant(resize_to_limit: [100, 100]))
    get path(thumbnail)
    expect(response).to have_http_status(:forbidden)
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: member.create_new_auth_token
    get path(thumbnail)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('image/png')
    conversation.update!(assignee: colleague)
    get path(thumbnail)
    expect(response).to have_http_status(:forbidden)
    get legacy
    expect(response).to have_http_status(:forbidden)
  end
end

inbox_template = Current.account_user&.administrator? ? 'api/v1/models/inbox' : 'api/v1/models/inbox_member'
json.payload do
  json.array! @inboxes do |inbox|
    json.partial! inbox_template, formats: [:json], resource: inbox
  end
end

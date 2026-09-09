# Only transport metadata required to work on an assigned Conversation.
json.partial! 'api/v1/models/inbox_slim', formats: [:json], resource: resource
json.phone_number resource.channel.try(:phone_number)
json.allow_messages_after_resolved resource.allow_messages_after_resolved
json.sender_name_type resource.sender_name_type
json.enable_email_collect resource.enable_email_collect
if resource.whatsapp?
  templates = resource.channel.try(:message_templates)
  json.message_templates templates.is_a?(Array) ? templates : []
end

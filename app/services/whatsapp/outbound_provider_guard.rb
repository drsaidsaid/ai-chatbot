module Whatsapp::OutboundProviderGuard
  def send_message(phone_number, message)
    Whatsapp::OutboundDispatch.new(message: message, channel: whatsapp_channel, recipient: phone_number).perform do |request|
      super(phone_number, message, &request)
    end
  end

  def send_template(phone_number, template_info, message)
    Whatsapp::OutboundDispatch.new(message: message, channel: whatsapp_channel, recipient: phone_number, template: template_info).perform do |request|
      super(phone_number, template_info, message, &request)
    end
  end
end

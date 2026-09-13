#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ipaddr'
require 'socket'
require 'uri'

begin
  url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL')
  uri = URI.parse(url)
  raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host

  addresses = Addrinfo.getaddrinfo(uri.host, nil).map { |entry| IPAddr.new(entry.ip_address) }
  abort 'R26 acceptance blocked: WHATSAPP_CLOUD_BASE_URL must resolve only to loopback.' unless addresses.any? && addresses.all?(&:loopback?)

  abort 'R26 acceptance blocked: provide a command to execute.' if ARGV.empty?

  exec(*ARGV)
rescue KeyError, URI::InvalidURIError, SocketError, IPAddr::InvalidAddressError
  abort 'R26 acceptance blocked: WHATSAPP_CLOUD_BASE_URL must be an explicit loopback URL.'
end

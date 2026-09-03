# frozen_string_literal: true

require_relative "http"
require_relative "resources/payments"
require_relative "resources/payouts"
require_relative "resources/p2p"
require_relative "resources/orders"
require_relative "resources/terminal"

module Allpaypayz
  class Client
    DEFAULT_BASE_URL = "https://api4.allpaypayz.com"
    BASE_USER_AGENT = "Allpaypayz-SDK-Ruby/#{VERSION}".freeze

    attr_reader :payments, :payouts, :p2p, :orders, :terminal

    def initialize(api_key:, base_url: DEFAULT_BASE_URL, api_version: nil,
                   retry_options: nil, user_agent: nil,
                   open_timeout: 10, read_timeout: 30)
      raise ArgumentError, "Allpaypayz: api_key is required" if api_key.nil? || api_key.empty?

      ua = user_agent ? "#{BASE_USER_AGENT} #{user_agent}" : BASE_USER_AGENT
      @http = Http.new(
        api_key: api_key,
        base_url: base_url,
        user_agent: ua,
        api_version: api_version,
        retry_options: retry_options,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
      )
      @payments = Resources::Payments.new(@http)
      @payouts  = Resources::Payouts.new(@http)
      @p2p      = Resources::P2P.new(@http)
      @orders   = Resources::Orders.new(@http)
      @terminal = Resources::Terminal.new(@http)
    end
  end
end

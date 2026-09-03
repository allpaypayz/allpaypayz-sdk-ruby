# frozen_string_literal: true

require "uri"

module Allpaypayz
  module Resources
    class P2P
      def initialize(http)
        @http = http
      end

      def create(body, idempotency_key: nil)
        @http.request("POST", "/v4/p2p-transfers", body: body, idempotency_key: idempotency_key).fetch("data")
      end

      def confirm(id, body, idempotency_key: nil)
        @http.request(
          "POST",
          "/v4/p2p-transfers/#{URI.encode_www_form_component(id)}/confirm",
          body: body, idempotency_key: idempotency_key,
        ).fetch("data")
      end

      def get(id)
        @http.request("GET", "/v4/p2p-transfers/#{URI.encode_www_form_component(id)}").fetch("data")
      end

      def find_by_reference(merchant_reference)
        @http.request("GET", "/v4/p2p-transfers", query: { "merchant_reference" => merchant_reference }).fetch("data")
      end
    end
  end
end

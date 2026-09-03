# frozen_string_literal: true

require "uri"

module Allpaypayz
  module Resources
    class Payments
      def initialize(http)
        @http = http
      end

      def create(body, idempotency_key: nil)
        @http.request("POST", "/v4/payments", body: body, idempotency_key: idempotency_key).fetch("data")
      end

      def create_redirect(body, idempotency_key: nil)
        @http.request("POST", "/v4/payments/redirect", body: body, idempotency_key: idempotency_key).fetch("data")
      end

      def recurrent(body, idempotency_key: nil)
        @http.request("POST", "/v4/payments/recurrent", body: body, idempotency_key: idempotency_key).fetch("data")
      end

      def finish_3ds(id, body, idempotency_key: nil)
        @http.request(
          "POST",
          "/v4/payments/#{URI.encode_www_form_component(id)}/finish-3ds",
          body: body, idempotency_key: idempotency_key,
        ).fetch("data")
      end

      def get(id)
        @http.request("GET", "/v4/payments/#{URI.encode_www_form_component(id)}").fetch("data")
      end

      def find_by_reference(merchant_reference)
        @http.request("GET", "/v4/payments", query: { "merchant_reference" => merchant_reference }).fetch("data")
      end

      def create_refund(payment_id, body, idempotency_key: nil)
        @http.request(
          "POST",
          "/v4/payments/#{URI.encode_www_form_component(payment_id)}/refunds",
          body: body, idempotency_key: idempotency_key,
        ).fetch("data")
      end

      def get_refund(payment_id, refund_id)
        path = "/v4/payments/#{URI.encode_www_form_component(payment_id)}" \
               "/refunds/#{URI.encode_www_form_component(refund_id)}"
        @http.request("GET", path).fetch("data")
      end
    end
  end
end

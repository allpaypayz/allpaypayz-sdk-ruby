# frozen_string_literal: true

require "openssl"
require "json"

module Allpaypayz
  module Webhooks
    SIGNATURE_REGEX = /\At=(\d+),v1=([0-9a-fA-F]+)\z/.freeze

    # Verify a Allpaypayz webhook delivery.
    #
    # Parses ``t=<unix>,v1=<hex>`` from the Callback-Signature header,
    # recomputes HMAC-SHA256(t + "." + raw_body, sign_key), runs a
    # constant-time compare via OpenSSL.secure_compare, rejects deliveries
    # whose ``t`` is more than +tolerance_seconds+ away from +now+.
    #
    # Returns the parsed ``event`` field of the envelope on success;
    # raises Allpaypayz::WebhookError on every failure mode.
    def self.verify(raw_body, signature_header, sign_key:, tolerance_seconds: 300, now: nil)
      match = SIGNATURE_REGEX.match(signature_header.to_s.strip)
      unless match
        raise WebhookError.new("invalid_signature_header",
                               "Malformed Callback-Signature: #{signature_header}")
      end
      ts = match[1].to_i
      provided = match[2].downcase

      expected = OpenSSL::HMAC.hexdigest("sha256", sign_key, "#{ts}.#{raw_body}")
      unless OpenSSL.fixed_length_secure_compare(expected, provided)
        raise WebhookError.new("signature_mismatch", "Webhook signature does not match")
      end

      current = (now || Time.now.to_i)
      if (current - ts).abs > tolerance_seconds
        raise WebhookError.new(
          "stale_delivery",
          "Webhook timestamp #{ts} outside #{tolerance_seconds}s tolerance (now=#{current})",
        )
      end

      raise WebhookError.new("invalid_envelope", "Webhook body is empty") if raw_body.nil? || raw_body.empty?

      parsed = begin
        JSON.parse(raw_body)
      rescue JSON::ParserError => e
        raise WebhookError.new("invalid_json", "Webhook body is not valid JSON: #{e.message}")
      end

      event = parsed["event"] if parsed.is_a?(Hash)
      unless event.is_a?(Hash) && event.key?("type")
        raise WebhookError.new("invalid_envelope", "Webhook envelope missing event field")
      end
      event
    end
  end

  class WebhookDispatcher
    def initialize
      @handlers = {}
    end

    def on(event_type, &handler)
      @handlers[event_type] = handler
      self
    end

    def dispatch(event)
      type = event["type"]
      handler = @handlers[type]
      handler&.call(event)
    end
  end
end

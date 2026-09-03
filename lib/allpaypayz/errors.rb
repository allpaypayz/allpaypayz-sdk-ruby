# frozen_string_literal: true

module Allpaypayz
  # Base class for every SDK error. Carries the v4 ApiError fields plus the
  # HTTP status.
  class Error < StandardError
    attr_reader :type, :code, :status, :request_id, :details, :retry_after_seconds

    def initialize(type:, code:, message:, status: nil, request_id: nil, details: nil, retry_after_seconds: nil)
      super(message)
      @type = type
      @code = code
      @status = status
      @request_id = request_id
      @details = details
      @retry_after_seconds = retry_after_seconds
    end
  end

  class ValidationError      < Error; end
  class AuthenticationError  < Error; end
  class NotFoundError        < Error; end
  class ConflictError        < Error; end
  class BusinessError        < Error; end
  class RateLimitError       < Error; end
  class GatewayError         < Error; end
  class NetworkError         < Error; end

  class WebhookError < StandardError
    attr_reader :code

    def initialize(code, message)
      super(message)
      @code = code
    end
  end

  class << self
    # @api private — used by the HTTP layer to build the right subclass.
    def build_api_error(status, payload, retry_after)
      err = (payload || {})["error"] || {}
      type = err["type"] || status_to_type(status)
      klass = type_to_class(type)
      klass.new(
        type: type,
        code: err["code"] || "http_#{status}",
        message: err["message"] || "Request failed with status #{status}",
        status: status,
        request_id: (payload || {})["request_id"],
        details: err["details"],
        retry_after_seconds: retry_after,
      )
    end

    def status_to_type(status)
      case status
      when 400 then "validation"
      when 401, 403 then "authentication"
      when 404 then "not_found"
      when 409 then "conflict"
      when 422 then "business"
      when 429 then "rate_limit"
      when 500..599 then "gateway"
      else "api"
      end
    end

    def type_to_class(type)
      {
        "validation"     => ValidationError,
        "authentication" => AuthenticationError,
        "not_found"      => NotFoundError,
        "conflict"       => ConflictError,
        "business"       => BusinessError,
        "rate_limit"     => RateLimitError,
        "gateway"        => GatewayError,
      }.fetch(type, Error)
    end
  end
end

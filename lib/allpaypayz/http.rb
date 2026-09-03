# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "time"
require "uri"

module Allpaypayz
  RetryOptions = Struct.new(
    :max_attempts, :initial_backoff_seconds, :max_backoff_seconds, :jitter_seconds,
    keyword_init: true,
  ) do
    def self.defaults
      new(
        max_attempts: 3,
        initial_backoff_seconds: 0.25,
        max_backoff_seconds: 4.0,
        jitter_seconds: 0.25,
      )
    end
  end

  # Internal HTTP layer wrapping Net::HTTP with the cross-SDK consistency
  # matrix items (auth, idempotency, retries, error mapping).
  class Http
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

    def initialize(api_key:, base_url:, user_agent:, api_version: nil,
                   retry_options: nil, open_timeout: 10, read_timeout: 30)
      @api_key = api_key
      @base_url = base_url.chomp("/")
      @user_agent = user_agent
      @api_version = api_version
      @retry = retry_options || RetryOptions.defaults
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def request(method, path, body: nil, query: nil, idempotency_key: nil)
      uri = build_uri(path, query)
      attempt = 0
      last_error = nil

      while attempt < @retry.max_attempts
        attempt += 1
        request = build_request(method, uri, body, idempotency_key)
        begin
          response = perform(uri, request)
        rescue StandardError => e
          if attempt < @retry.max_attempts
            sleep_backoff(attempt, nil)
            last_error = e
            next
          end
          raise NetworkError.new(
            type: "network", code: "network_error", message: e.message,
          )
        end

        status = response.code.to_i
        if status < 400
          return parse_json(response.body)
        end

        retry_after = parse_retry_after(response["Retry-After"])
        payload = safe_json(response.body)
        api_err = Allpaypayz.build_api_error(status, payload, retry_after)

        if RETRYABLE_STATUSES.include?(status) && attempt < @retry.max_attempts
          sleep_backoff(attempt, retry_after)
          last_error = api_err
          next
        end
        raise api_err
      end
      raise last_error if last_error
    end

    private

    def build_uri(path, query)
      uri = URI.parse(@base_url + (path.start_with?("/") ? path : "/#{path}"))
      if query && !query.empty?
        params = query.reject { |_, v| v.nil? }
        uri.query = URI.encode_www_form(params)
      end
      uri
    end

    def build_request(method, uri, body, idempotency_key)
      klass = {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "PUT" => Net::HTTP::Put,
        "DELETE" => Net::HTTP::Delete,
        "PATCH" => Net::HTTP::Patch,
      }.fetch(method.to_s.upcase)
      req = klass.new(uri.request_uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["User-Agent"] = @user_agent
      req["Accept"] = "application/json"
      req["Accept-Api-Version"] = @api_version if @api_version
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.dump(body)
      end
      if method.to_s.upcase == "POST"
        req["Idempotency-Key"] = idempotency_key || SecureRandom.uuid
      end
      req
    end

    def perform(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http.request(request)
    end

    def parse_json(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Error.new(type: "api", code: "invalid_json_response", message: e.message)
    end

    def safe_json(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def parse_retry_after(value)
      return nil if value.nil? || value.to_s.empty?
      return value.to_i if value.to_s.match?(/\A\d+\z/)

      begin
        ts = Time.httpdate(value)
        delta = ts.to_i - Time.now.to_i
        return delta.negative? ? 0 : delta
      rescue ArgumentError
        nil
      end
    end

    def sleep_backoff(attempt, retry_after)
      if retry_after
        sleep(retry_after)
        return
      end
      exp = [@retry.max_backoff_seconds, @retry.initial_backoff_seconds * (2**(attempt - 1))].min
      sleep(exp + rand(0.0..@retry.jitter_seconds))
    end
  end
end

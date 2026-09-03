# frozen_string_literal: true

module Allpaypayz
  module Resources
    class Terminal
      def initialize(http)
        @http = http
      end

      def get
        @http.request("GET", "/v4/terminal").fetch("data")
      end
    end
  end
end

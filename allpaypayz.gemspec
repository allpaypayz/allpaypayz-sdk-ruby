# frozen_string_literal: true

require_relative "lib/allpaypayz/version"

Gem::Specification.new do |spec|
  spec.name          = "allpaypayz"
  spec.version       = Allpaypayz::VERSION
  spec.authors       = ["Allpaypays"]
  spec.summary       = "Official Allpaypayz API v4 SDK for Ruby."
  spec.description   = "Typed client for the Allpaypayz payments API: payments, payouts, p2p, orders, webhooks."
  spec.homepage      = "https://github.com/allpaypayz/allpaypayz-sdk-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.20"
  spec.add_development_dependency "rake", "~> 13.0"

  spec.metadata = {
    "source_code_uri" => "https://github.com/allpaypayz/allpaypayz-sdk-ruby",
    "rubygems_mfa_required" => "true",
  }
end

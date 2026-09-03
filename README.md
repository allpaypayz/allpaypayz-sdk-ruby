# `allpaypayz` (Ruby)

**[⬇ Download the latest version](https://github.com/allpaypayz/allpaypayz-sdk-ruby/archive/refs/heads/main.zip)** · [Browse the code](https://github.com/allpaypayz/allpaypayz-sdk-ruby) · [MIT](LICENSE)

<sub>The archive is a snapshot of `main` — the current state of the SDK. Tagged releases will appear on the Releases page once the code leaves alpha.</sub>


Official Allpaypayz API v4 SDK for Ruby.

> Status: **alpha** (v0.1.0). Requires Ruby 3.0+.

## Install

```bash
gem install allpaypayz
```

Or in a Gemfile:

```ruby
gem "allpaypayz", "~> 0.1"
```

Zero runtime gem dependencies — uses stdlib `Net::HTTP`, `OpenSSL`, and `JSON`.

## Quick start

```ruby
require "allpaypayz"

client = Allpaypayz::Client.new(api_key: ENV.fetch("ALLPAYPAYZ_API_KEY"))

payment = client.payments.create(
  merchant_reference: "ORDER-77",
  amount: { amount_minor: 1000, currency: "USD" },
  description: "Order #77",
  customer: { name: "Jane Doe", email: "jane@example.com" },
  card: { pan: "4111111111111111", exp_month: 12, exp_year: 2029,
          cvc: "123", holder: "JANE DOE" },
)

if payment["status"] == "requires_action"
  # Redirect customer through payment["three_ds"]["acs_url"]
end
```

`Idempotency-Key` is auto-generated as a UUIDv4 from `SecureRandom` on every
POST. Override via `idempotency_key: "my-key"` kwarg.

## Configuration

```ruby
Allpaypayz::Client.new(
  api_key: "sk_test_...",
  base_url: "https://staging-api4.allpaypayz.com",
  api_version: "2026-05-20",
  open_timeout: 10,
  read_timeout: 30,
  retry_options: Allpaypayz::RetryOptions.new(
    max_attempts: 3,
    initial_backoff_seconds: 0.25,
    max_backoff_seconds: 4.0,
    jitter_seconds: 0.25,
  ),
  user_agent: "MyApp/2.0",
)
```

## Resources

| Resource | Methods |
|---|---|
| `client.payments` | `create`, `create_redirect`, `recurrent`, `finish_3ds`, `get`, `find_by_reference`, `create_refund`, `get_refund` |
| `client.payouts`  | `create`, `get`, `find_by_reference` |
| `client.p2p`      | `create`, `confirm`, `get`, `find_by_reference` |
| `client.orders`   | `create`, `get`, `find_by_reference` |
| `client.terminal` | `get` |

Methods take a hash for the body, return a hash (the `data` field of the v4
envelope).

## Errors

```ruby
begin
  client.payments.create(req)
rescue Allpaypayz::ConflictError => e
  if e.code == "duplicate_reference"
    # merchant_reference already used on this terminal
  end
end
```

| HTTP / `error.type` | Class |
|---|---|
| `400` / `validation` | `Allpaypayz::ValidationError` |
| `401`, `403` / `authentication` | `Allpaypayz::AuthenticationError` |
| `404` / `not_found` | `Allpaypayz::NotFoundError` |
| `409` / `conflict` | `Allpaypayz::ConflictError` |
| `422` / `business` | `Allpaypayz::BusinessError` |
| `429` / `rate_limit` | `Allpaypayz::RateLimitError` (`#retry_after_seconds`) |
| `5xx` / `gateway` | `Allpaypayz::GatewayError` |
| Network / transport | `Allpaypayz::NetworkError` |

Each exposes `#type`, `#code`, `#status`, `#request_id`, `#details`,
`#retry_after_seconds`.

## Webhooks

```ruby
# Rails / Rack
require "allpaypayz"

dispatcher = Allpaypayz::WebhookDispatcher.new
dispatcher.on("payment.succeeded") { |event| mark_order_paid(event["resource"]["merchant_reference"]) }
dispatcher.on("payment.failed")    { |event| mark_order_failed(event["resource"]["merchant_reference"]) }

post "/webhooks/allpaypayz" do
  raw = request.body.read
  begin
    event = Allpaypayz::Webhooks.verify(raw, request.env["HTTP_CALLBACK_SIGNATURE"],
                                         sign_key: ENV.fetch("ALLPAYPAYZ_SIGN_KEY"))
  rescue Allpaypayz::WebhookError => e
    halt 400, e.code
  end
  dispatcher.dispatch(event)
  status 200
end
```

`Allpaypayz::Webhooks.verify` parses `Callback-Signature` (`t=<unix>,v1=<hex>`),
recomputes `HMAC-SHA256(t + "." + raw_body, sign_key)` via
`OpenSSL::HMAC.hexdigest` and `OpenSSL.fixed_length_secure_compare` for
constant-time comparison, rejects deliveries outside the 300 s tolerance
window (`tolerance_seconds:` kwarg to override).

## Tests

```bash
bundle install
bundle exec rspec
```

`spec/webhooks_spec.rb` loads `../spec/test-vectors.json` and guarantees
byte-identity with every other Allpaypayz SDK. `spec/client_spec.rb` uses
WebMock to stub HTTP responses.

## License

MIT

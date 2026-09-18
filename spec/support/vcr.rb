require "webmock/rspec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false

  config.filter_sensitive_data("<CURRENCYLAYER_API_KEY>") { ENV["CURRENCYLAYER_API_KEY"] }
  config.filter_sensitive_data("<FREECURRENCYAPI_API_KEY>") { ENV["FREECURRENCYAPI_API_KEY"] }
end

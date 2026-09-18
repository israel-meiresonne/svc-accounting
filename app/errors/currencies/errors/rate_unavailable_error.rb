class Currencies::Errors::RateUnavailableError < BaseError
  CODE = "currency_rate_unavailable"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "No exchange rate is available for this currency"
end

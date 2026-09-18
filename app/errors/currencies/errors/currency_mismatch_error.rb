class Currencies::Errors::CurrencyMismatchError < BaseError
  CODE = "currency_mismatch"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "Currencies do not match"
end

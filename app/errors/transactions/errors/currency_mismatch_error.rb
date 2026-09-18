class Transactions::Errors::CurrencyMismatchError < BaseError
  CODE = "currency_mismatch"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "The destination account's currency doesn't match every selected transaction"
end

class Accounts::Errors::CurrencyChangeNotAllowedError < BaseError
  CODE = "currency_change_not_allowed"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "Cannot change currency: this account has existing transactions"
end

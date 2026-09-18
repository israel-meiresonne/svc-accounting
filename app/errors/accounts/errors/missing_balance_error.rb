class Accounts::Errors::MissingBalanceError < BaseError
  CODE = "missing_balance"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "Provide either an initial balance or a current balance"
end

class Transactions::Errors::MissingCounterpartyError < BaseError
  CODE = "missing_counterparty"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "Provide either an existing counterparty or new counterparty details"
end

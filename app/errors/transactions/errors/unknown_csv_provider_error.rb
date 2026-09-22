class Transactions::Errors::UnknownCsvProviderError < BaseError
  CODE = "unknown_csv_provider"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "No CSV formatter is registered for this provider"
end

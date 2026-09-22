class Transactions::Errors::InvalidCsvColumnsError < BaseError
  CODE = "invalid_csv_columns"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "This CSV doesn't have the columns expected for this provider"
end

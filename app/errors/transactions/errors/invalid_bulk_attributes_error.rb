class Transactions::Errors::InvalidBulkAttributesError < BaseError
  CODE = "invalid_bulk_attributes"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "One or more attributes cannot be bulk-updated"
end

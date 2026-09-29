class Transactions::Errors::BulkUpdateRowError < BaseError
  CODE = "bulk_update_row_failed"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "A row in the bulk update CSV failed, so no changes were made"
end

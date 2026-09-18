class Transactions::Errors::EmptySelectionError < BaseError
  CODE = "empty_selection"
  HTTP_STATUS = :unprocessable_entity
  DEFAULT_MESSAGE = "Select at least one transaction"
end

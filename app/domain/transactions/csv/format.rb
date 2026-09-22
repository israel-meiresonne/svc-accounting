module Transactions::Csv::Format
  OUTPUT_COLUMNS = %w[
    occurred_at
    amount
    currency
    payment_method
    category
    description
    account
    counterparty_type
    counterparty_name
    counterparty_email
  ].freeze
end

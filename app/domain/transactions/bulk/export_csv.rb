class Transactions::Bulk::ExportCsv
  include Interactor::Initializer
  include Transactions::Scoped

  HEADERS = %w[date amount currency category payment_method counterparty description account].freeze

  CELL_EXTRACTORS = {
    "date" => ->(transaction) { transaction.occurred_at.to_date.iso8601 },
    "counterparty" => ->(transaction) { transaction.counterparty_display_name },
    "account" => ->(transaction) { transaction.account_name }
  }.freeze

  initialize_with_keyword_params :user, :transaction_codes

  def run
    CSV.generate do |csv|
      csv << HEADERS
      scoped_transactions.includes(:account, :counterparty).find_each { |transaction| csv << row_for(transaction) }
    end
  end

  private

  def row_for(transaction)
    HEADERS.map { |header| sanitized_cell(transaction, header) }
  end

  def sanitized_cell(transaction, header)
    CsvSanitizers::CsvSafety.sanitize_cell(cell_value(transaction, header))
  end

  def cell_value(transaction, header)
    extractor = CELL_EXTRACTORS[header]
    extractor ? extractor.call(transaction) : transaction.public_send(header)
  end
end

class Transactions::Bulk::UpdateFromCsv
  include Interactor::Initializer

  CODE_COLUMN = "code"
  ATTRIBUTE_COLUMNS = %w[
    amount
    category
    description
    payment_method
    occurred_at
  ].freeze

  initialize_with_keyword_params :csv_rows

  def run
    validate_columns!

    ActiveRecord::Base.transaction do
      csv_rows.each { |row| update_row(row) }
    end
  end

  private

  def validate_columns!
    raise_invalid_columns unless code_column_present? && attribute_column_present? && no_unknown_columns?
  end

  def code_column_present?
    headers.include?(CODE_COLUMN)
  end

  def attribute_column_present?
    (headers & ATTRIBUTE_COLUMNS).any?
  end

  def no_unknown_columns?
    (headers - [ CODE_COLUMN ] - ATTRIBUTE_COLUMNS).empty?
  end

  def headers
    csv_rows.headers
  end

  def raise_invalid_columns
    raise Transactions::Errors::InvalidCsvColumnsError.new(details: { headers: headers })
  end

  def update_row(row)
    transaction = Transaction.find_by!(code: row[CODE_COLUMN])
    Transactions::Update.for(transaction: transaction, attributes: attributes_for(row))
  rescue StandardError => e
    raise_row_failed(row[CODE_COLUMN], e.message)
  end

  def raise_row_failed(code, reason)
    raise Transactions::Errors::BulkUpdateRowError.new(details: { code: code, reason: reason })
  end

  def attributes_for(row)
    present_attribute_columns(row).index_with { |column| row[column] }.transform_keys(&:to_sym)
  end

  def present_attribute_columns(row)
    ATTRIBUTE_COLUMNS.select { |column| row[column].present? }
  end
end

module Transactions::Csv::Import::FieldMapping
  private

  def csv_row_attributes(row)
    {
      occurred_at: row[:occurred_at],
      amount: row[:amount],
      currency: row[:currency],
      payment_method: row[:payment_method],
      category: row[:category],
      description: row[:description]
    }
  end
end

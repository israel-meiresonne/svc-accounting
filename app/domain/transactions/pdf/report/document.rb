class Transactions::Pdf::Report::Document
  COLUMNS = [ "Date", "Amount", "Currency", "Category", "Counterparty" ].freeze
  HEADER = ->(_table) { [ COLUMNS ] }

  def initialize(title:, description:, transactions:, net_balance:)
    @title = title
    @description = description
    @transactions = transactions
    @net_balance = net_balance
  end

  def render
    composer.write_to_string
  end

  private

  attr_reader :title, :description, :transactions, :net_balance

  def composer
    @composer ||= HexaPDF::Composer.new { |pdf| draw(pdf) }
  end

  def draw(pdf)
    pdf.text(title, font_size: 20)
    pdf.text(description)
    pdf.table(rows, header: HEADER)
    pdf.text("Net balance: #{net_balance}")
  end

  def rows
    transactions.map(&method(:row_for))
  end

  def row_for(transaction)
    [
      transaction.occurred_at.to_date.iso8601,
      transaction.amount.to_s,
      transaction.currency,
      transaction.category.to_s,
      transaction.counterparty_display_name
    ]
  end
end

class Transactions::Pdf::Report::Build
  include Interactor::Initializer
  include Transactions::Scoped

  initialize_with_keyword_params :user, :transaction_codes, :title, :description, :reporting_currency

  def run
    numbers = net_balance
    build_document(numbers)
  end

  private

  def net_balance
    Transactions::Pdf::Report::ExtractNumbers.for(transactions: transactions, reporting_currency: reporting_currency)
  end

  def build_document(net_balance)
    Transactions::Pdf::Report::Document.new(title: title, description: description, transactions: transactions, net_balance: net_balance).render
  end

  def transactions
    @transactions ||= scoped_transactions.includes(:account, :counterparty).to_a.tap do |found|
      raise Transactions::Errors::EmptySelectionError if found.empty?
    end
  end
end

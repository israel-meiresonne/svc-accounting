class Transactions::Pdf::Report::ExtractNumbers
  include Interactor::Initializer

  initialize_with_keyword_params :transactions, :reporting_currency

  def run
    transactions.map(&method(:normalized_money)).reduce(:+) || zero
  end

  private

  def normalized_money(transaction)
    Currencies::Convert.for(transaction.money, reporting_currency)
  end

  def zero
    Currencies::Money.new(amount: 0, currency: reporting_currency)
  end
end

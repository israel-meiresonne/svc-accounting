class Accounts::SumAll
  include Interactor::Initializer

  initialize_with_keyword_params :accounts, :currency

  def run
    accounts.sum(zero) { |account| converted_balance(account) }
  end

  private

  def zero
    Currencies::Money.new(amount: 0, currency: currency)
  end

  def converted_balance(account)
    Currencies::Convert.for(account.balance, currency)
  end
end

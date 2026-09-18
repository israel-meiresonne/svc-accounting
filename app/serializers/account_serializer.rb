class AccountSerializer
  def initialize(account)
    @account = account
  end

  def as_json(*)
    {
      code: account.code,
      name: account.name,
      currency: account.currency,
      balance: account.balance,
      has_transactions: account.has_transactions?
    }
  end

  private

  attr_reader :account
end

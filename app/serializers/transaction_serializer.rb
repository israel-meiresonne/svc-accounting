class TransactionSerializer
  def initialize(transaction)
    @transaction = transaction
  end

  def as_json(*)
    {
      code: transaction.code,
      occurred_at: transaction.occurred_at,
      amount: transaction.amount.to_s,
      currency: transaction.currency,
      category: transaction.category,
      payment_method: transaction.payment_method,
      description: transaction.description,
      counterparty: counterparty_json(transaction.counterparty),
      account: account_json(transaction.account)
    }
  end

  private

  attr_reader :transaction

  def counterparty_json(counterparty)
    { code: counterparty.code, display_name: counterparty.display_name }
  end

  def account_json(account)
    { code: account.code, name: account.name, currency: account.currency }
  end
end

class Transactions::Create
  include Interactor::Initializer

  initialize_with_keyword_params :account, :amount, :category, :description, :payment_method, :occurred_at, :counterparty_id, :counterparty_options

  def run
    raise Transactions::Errors::MissingCounterpartyError if counterparty_id.nil? && counterparty_options.nil?

    transaction.save!
    resolve_account_balance
    transaction
  end

  private

  def resolve_account_balance
    Accounts::ResolveBalanceAtCreation.for(account)
  end

  def transaction
    @transaction ||= account.transactions.new(
      amount: amount,
      currency: account.currency,
      category: category,
      description: description,
      payment_method: payment_method,
      occurred_at: occurred_at,
      counterparty: counterparty,
    )
  end

  def counterparty
    @counterparty ||= counterparty_id ? User.find(counterparty_id) : Users::ResolveCounterparty.for(counterparty_options)
  end
end

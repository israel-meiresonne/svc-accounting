module Transactions::Scoped
  private

  def scoped_transactions
    Transaction.active.joins(:account).where(accounts: { user_id: user.id }, code: transaction_codes)
  end
end

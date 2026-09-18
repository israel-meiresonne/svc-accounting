class Accounts::ResolveBalanceAtCreation
  include Interactor::Initializer

  initialize_with :account

  def run
    return unless account.balance_at_creation

    account.update!(
      initial_balance: account.balance_at_creation - account.active_transactions_sum,
      balance_at_creation: nil,
    )
  end
end

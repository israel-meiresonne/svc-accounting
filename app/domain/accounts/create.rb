class Accounts::Create
  include Interactor::Initializer

  initialize_with_keyword_params :user, :name, :currency, :initial_balance, :current_balance

  def run
    raise Accounts::Errors::MissingBalanceError if initial_balance.nil? && current_balance.nil?

    account.save!
    account
  end

  private

  def account
    @account ||= user.accounts.new(name: name, currency: currency, **balance_attributes)
  end

  def balance_attributes
    return { initial_balance: initial_balance } if initial_balance.present?

    { initial_balance: current_balance, balance_at_creation: current_balance }
  end
end

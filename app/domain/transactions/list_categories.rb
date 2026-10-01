class Transactions::ListCategories
  include Interactor::Initializer

  initialize_with :user

  def run
    Transaction
      .active
      .where(account: user.accounts.active)
      .where.not(category: [ nil, "" ])
      .distinct
      .pluck(:category)
      .sort
  end
end

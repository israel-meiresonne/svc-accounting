class Accounts::Delete
  include Interactor::Initializer

  initialize_with :account

  def run
    account.soft_delete!
  end
end

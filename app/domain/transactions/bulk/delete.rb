class Transactions::Bulk::Delete
  include Interactor::Initializer
  include Transactions::Scoped

  initialize_with_keyword_params :user, :transaction_codes

  def run
    scoped_transactions.update_all(deleted_at: Time.current)
  end
end

class Users::SearchCounterparties
  include Interactor::Initializer

  COUNTERPARTY_TYPES = %w[contact company].freeze
  NAME_MATCH = "first_name ILIKE :query OR last_name ILIKE :query OR company_name ILIKE :query".freeze
  RESULT_LIMIT = 10

  initialize_with_keyword_params :user, :query

  def run
    searchable_users.where(NAME_MATCH, query: "%#{query}%").limit(RESULT_LIMIT)
  end

  private

  def searchable_users
    User.where(type: COUNTERPARTY_TYPES).or(User.where(id: transacted_counterparty_ids))
  end

  def transacted_counterparty_ids
    user.accounts.joins(:transactions).select("transactions.counterparty_id")
  end
end

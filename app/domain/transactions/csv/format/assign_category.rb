class Transactions::Csv::Format::AssignCategory
  include Interactor::Initializer

  initialize_with_keyword_params :user, :description, :counterparty_name

  def run
    return if counterparty_name.blank?

    matching_transaction&.category
  end

  private

  def matching_transaction
    candidates.find { |transaction| matches_counterparty?(transaction) }
  end

  def candidates
    Transaction
      .joins(:account)
      .includes(:counterparty)
      .where(accounts: { user_id: user.id })
      .where("LOWER(TRIM(transactions.description)) = ?", normalized_description)
      .where.not(category: [ nil, "" ])
      .order(occurred_at: :desc)
  end

  def matches_counterparty?(transaction)
    normalize(transaction.counterparty.display_name) == normalize(counterparty_name)
  end

  def normalized_description
    normalize(description)
  end

  def normalize(value)
    value.to_s.strip.downcase
  end
end

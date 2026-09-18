class Transactions::Search
  include Interactor::Initializer

  SORTABLE_COLUMNS = %w[occurred_at amount category payment_method].freeze

  initialize_with_keyword_params :user, :from, :to, :filters, :sort, :order, :page, :per_page

  def run
    scoped_transactions
      .then(&method(:filter_by_range))
      .then(&method(:filter_by_account))
      .then(&method(:filter_by_category))
      .then(&method(:filter_by_payment_method))
      .order(sort_column => sort_order)
      .page(page)
      .per(bounded_per_page)
  end

  private

  def scoped_transactions
    Transaction.active.joins(:account).where(accounts: { user_id: user.id })
  end

  def filter_by_range(transactions)
    return transactions unless from && to

    transactions.in_range(from, to)
  end

  def filter_by_account(transactions)
    return transactions if filters[:account_codes].blank?

    transactions.where(accounts: { code: filters[:account_codes] })
  end

  def filter_by_category(transactions)
    return transactions if filters[:category].blank?

    transactions.where(category: filters[:category])
  end

  def filter_by_payment_method(transactions)
    return transactions if filters[:payment_method].blank?

    transactions.where(payment_method: filters[:payment_method])
  end

  def sort_column
    SORTABLE_COLUMNS.include?(sort) ? sort : "occurred_at"
  end

  def sort_order
    order == "asc" ? :asc : :desc
  end

  def bounded_per_page
    [ per_page.to_i, 100 ].min
  end
end

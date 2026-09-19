class Transactions::CalculateStats
  include Interactor::Initializer

  initialize_with_keyword_params :account, :from, :to

  def run
    {
      total_income: money(income),
      total_expenses: money(expenses),
      net_balance: money(income - expenses)
    }
  end

  private

  def money(amount)
    Currencies::Money.new(amount: amount, currency: account.currency)
  end

  def transactions_in_range
    @transactions_in_range ||= account.transactions.active.where(occurred_at: from..to)
  end

  def income
    @income ||= transactions_in_range.where(transactions_in_range.arel_table[:amount].gt(0)).sum(:amount)
  end

  def expenses
    @expenses ||= transactions_in_range.where(transactions_in_range.arel_table[:amount].lt(0)).sum(:amount).abs
  end
end

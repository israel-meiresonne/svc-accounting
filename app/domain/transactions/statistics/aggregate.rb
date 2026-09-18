class Transactions::Statistics::Aggregate
  include Interactor::Initializer

  initialize_with_keyword_params :current_user, :from, :to, :account_codes, :category, :payment_method

  def run
    {
      currency: current_user.currency,
      current: with_forecast(summarize(from: from, to: to)),
      previous: summarize(from: previous_from, to: previous_to)
    }
  end

  private

  def previous_from = from - interval_length_in_days
  def previous_to = from - 1
  def interval_length_in_days = (to - from) + 1

  def summarize(from:, to:)
    transactions = filtered_transactions(from: from, to: to)
    daily_totals = daily_totals_for(transactions, from: from, to: to)
    latest = daily_totals.last

    {
      from: from.iso8601,
      to: to.iso8601,
      daily_totals: daily_totals,
      total_income: latest[:cumulative_income],
      total_expenses: latest[:cumulative_expenses],
      net_balance: latest[:cumulative_net_balance],
      income_by_category: grouped_by_category(transactions.where(amount: 0..)),
      expenses_by_category: grouped_by_category(transactions.where(amount: ..0))
    }
  end

  def with_forecast(result)
    result.merge(forecast_net_balance: forecast(result[:net_balance]))
  end

  def accounts
    scope = current_user.accounts.active
    scope = scope.where(code: account_codes) if account_codes.present?
    scope
  end

  def filtered_transactions(from:, to:)
    transactions = Transaction.active.where(account: accounts).in_range(from, to)
    transactions = transactions.where(category: category) if category.present?
    transactions = transactions.where(payment_method: payment_method) if payment_method.present?
    transactions
  end

  def daily_totals_for(transactions, from:, to:)
    grouped_by_date = transactions.group_by { |transaction| transaction.occurred_at.to_date }
    initial_state = { running: { income: BigDecimal(0), expenses: BigDecimal(0) }, rows: [] }

    (from..to).inject(initial_state) { |state, date| accumulate_date(state, date, grouped_by_date) }[:rows]
  end

  def accumulate_date(state, date, grouped_by_date)
    running = apply_day(state[:running], grouped_by_date[date] || [])
    { running: running, rows: state[:rows] + [ daily_total_row(date, running) ] }
  end

  def apply_day(running, day_transactions)
    day_transactions.reduce(running) { |totals, transaction| accumulate_transaction(totals, transaction) }
  end

  def accumulate_transaction(totals, transaction)
    converted = convert_to_current_user_currency(transaction)
    return { income: totals[:income] + converted, expenses: totals[:expenses] } if converted.positive?

    { income: totals[:income], expenses: totals[:expenses] + converted.abs }
  end

  def daily_total_row(date, running)
    {
      date: date.iso8601,
      cumulative_income: format_amount(running[:income]),
      cumulative_expenses: format_amount(running[:expenses]),
      cumulative_net_balance: format_amount(running[:income] - running[:expenses])
    }
  end

  def grouped_by_category(transactions)
    transactions
      .group_by(&:category)
      .map { |category, category_transactions| { category: category, amount: sum_converted(category_transactions) } }
      .sort_by { |row| -row[:amount].to_f }
  end

  def sum_converted(transactions)
    format_amount(transactions.sum { |transaction| convert_to_current_user_currency(transaction) }.abs)
  end

  def convert_to_current_user_currency(transaction)
    Currencies::Convert.for(transaction.money, current_user.currency).amount
  end

  def format_amount(amount)
    Currencies::Money.new(amount: amount, currency: current_user.currency).to_s
  end

  def days_elapsed = [ [ Date.current, to ].min - from + 1, 1 ].max

  def forecast(net_balance)
    return nil if Date.current < from
    return net_balance if days_elapsed >= interval_length_in_days

    format_amount(BigDecimal(net_balance) / days_elapsed * interval_length_in_days)
  end
end

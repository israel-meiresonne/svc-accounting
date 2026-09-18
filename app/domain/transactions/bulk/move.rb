class Transactions::Bulk::Move
  include Interactor::Initializer
  include Transactions::Scoped

  initialize_with_keyword_params :user, :transaction_codes, :destination_account_code

  def run
    raise_on_currency_mismatch
    scoped_transactions.update_all(account_id: destination.id)
  end

  private

  def raise_on_currency_mismatch
    return if mismatched_currencies.empty?

    details = { destination_currency: destination.currency, mismatched_currencies: mismatched_currencies }
    raise Transactions::Errors::CurrencyMismatchError.new(details: details)
  end

  def destination
    @destination ||= user.accounts.active.find_by!(code: destination_account_code)
  end

  def mismatched_currencies
    @mismatched_currencies ||= scoped_transactions.where.not(currency: destination.currency).distinct.pluck(:currency)
  end
end

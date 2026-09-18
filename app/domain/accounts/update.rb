class Accounts::Update
  include Interactor::Initializer

  initialize_with_keyword_params :account, :attributes

  def run
    raise Accounts::Errors::CurrencyChangeNotAllowedError if changing_currency? && account.transactions.active.exists?

    account.update!(attributes)
    account
  end

  private

  def changing_currency?
    attributes[:currency].present? && attributes[:currency] != account.currency
  end
end

class Currencies::Convert
  include Interactor::Initializer

  initialize_with :money, :to

  def run
    return money if money.currency == to

    Currencies::Money.new(amount: converted_amount, currency: to)
  end

  private

  def converted_amount
    usd_amount = money.currency == CurrencyRate::CENTRAL_CURRENCY ? money.amount : money.amount / rate_to(money.currency)
    to == CurrencyRate::CENTRAL_CURRENCY ? usd_amount : usd_amount * rate_to(to)
  end

  def rate_to(currency)
    existing_rate(currency) || fetched_rate(currency) ||
      raise(Currencies::Errors::RateUnavailableError.new(details: { currency: currency }))
  end

  def existing_rate(currency)
    CurrencyRate.find_by(left: CurrencyRate::CENTRAL_CURRENCY, right: currency)&.rate
  end

  # The `currencies:fetch_rates` rake task keeps rates fresh for currencies
  # already in use, but a currency's very first use has no rate row yet to
  # refresh — so its first conversion always fetches one live rather than
  # failing until that task next runs.
  def fetched_rate(currency)
    Currencies::FetchRate.for(currency)
    existing_rate(currency)
  end
end

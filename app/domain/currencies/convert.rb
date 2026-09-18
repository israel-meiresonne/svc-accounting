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
    CurrencyRate.find_by(left: CurrencyRate::CENTRAL_CURRENCY, right: currency)&.rate ||
      raise(Currencies::Errors::RateUnavailableError.new(details: { currency: currency }))
  end
end

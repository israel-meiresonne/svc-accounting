require "bigdecimal"

class Currencies::Money
  attr_reader :amount, :currency

  def initialize(amount:, currency:)
    @amount = BigDecimal(amount.to_s)
    @currency = currency
  end

  def +(other)
    raise Currencies::Errors::CurrencyMismatchError unless currency == other.currency

    self.class.new(amount: amount + other.amount, currency: currency)
  end

  def -(other)
    raise Currencies::Errors::CurrencyMismatchError unless currency == other.currency

    self.class.new(amount: amount - other.amount, currency: currency)
  end

  def to_s
    whole, _, fraction = amount.round(2).to_s("F").partition(".")
    "#{whole}.#{fraction.ljust(2, "0")}"
  end

  def as_json(*)
    { amount: to_s, currency: currency }
  end
end

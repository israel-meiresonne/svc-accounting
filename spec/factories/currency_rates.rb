FactoryBot.define do
  factory :currency_rate do
    left { CurrencyRate::CENTRAL_CURRENCY }
    right { "eur" }
    rate { 0.9 }
  end
end

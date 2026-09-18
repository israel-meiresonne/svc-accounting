class CurrencyRate < ApplicationRecord
  CENTRAL_CURRENCY = "usd"

  validates :left, :right, :rate, presence: true
end

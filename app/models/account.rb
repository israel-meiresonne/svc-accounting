class Account < ApplicationRecord
  include SoftDeletable

  belongs_to :user
  has_many :transactions

  before_validation :assign_code, on: :create

  validates :name, presence: true
  validates :currency, presence: true, format: { with: /\A[a-z]{3}\z/ }

  def balance
    active_transactions_sum.then { |total| Currencies::Money.new(amount: initial_balance + total, currency: currency) }
  end

  def active_transactions_sum
    transactions.active.sum(:amount)
  end

  def has_transactions?
    transactions.active.exists?
  end

  private

  def assign_code
    self.code = "acc_#{ULID.generate}"
  end
end

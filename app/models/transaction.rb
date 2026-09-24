class Transaction < ApplicationRecord
  include SoftDeletable

  enum :payment_method, {
    cash: "cash",
    debit_card: "debit_card",
    credit_card: "credit_card",
    bank_transfer: "bank_transfer",
    other: "other"
  }

  belongs_to :account
  belongs_to :counterparty, class_name: "User"

  delegate :display_name, to: :counterparty, prefix: true
  delegate :name, to: :account, prefix: true

  before_validation :assign_code, on: :create
  before_validation :assign_dedup_hash

  validates :occurred_at, presence: true
  validates :currency, presence: true
  validate :currency_matches_account

  scope :in_range, ->(from, to) { where(occurred_at: from.beginning_of_day..to.end_of_day) }

  def money
    Currencies::Money.new(amount: amount, currency: currency)
  end

  private

  def currency_matches_account
    return if account.nil? || currency == account.currency

    errors.add(:currency, "must match the account's currency (#{account&.currency})")
  end

  def assign_code
    self.code = "txn_#{ULID.generate}"
  end

  def assign_dedup_hash
    self.dedup_hash = Digest::SHA256.hexdigest([ occurred_at&.to_date&.iso8601, amount, currency, counterparty_id ].join("|"))
  end
end

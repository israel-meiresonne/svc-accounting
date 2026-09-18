class User < ApplicationRecord
  self.inheritance_column = nil

  TYPES = %w[user contact company].freeze

  has_secure_password validations: false

  has_many :accounts
  has_many :counterparty_transactions, class_name: "Transaction", foreign_key: :counterparty_id

  before_validation :assign_code, on: :create

  validates :type, inclusion: { in: TYPES }
  validates :email, uniqueness: true, allow_nil: true
  validates :password, presence: true, confirmation: true, on: :create, if: -> { user_type? }
  validates :email, presence: true, if: -> { user_type? }
  validates :currency, presence: true, format: { with: /\A[a-z]{3}\z/ }, if: -> { user_type? }
  validates :first_name, :last_name, presence: true, if: -> { user_type? || contact_type? }
  validates :company_name, presence: true, if: -> { company_type? }

  def user_type? = type == "user"
  def contact_type? = type == "contact"
  def company_type? = type == "company"

  def display_name
    company_type? ? company_name : "#{first_name} #{last_name}"
  end

  private

  def assign_code
    self.code = "usr_#{ULID.generate}"
  end
end

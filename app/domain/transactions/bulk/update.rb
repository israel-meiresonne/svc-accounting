class Transactions::Bulk::Update
  include Interactor::Initializer
  include Transactions::Scoped

  ALLOWED_ATTRIBUTES = %w[category payment_method description].freeze

  initialize_with_keyword_params :user, :transaction_codes, :attributes

  def run
    raise Transactions::Errors::InvalidBulkAttributesError.new(details: { disallowed: disallowed_attributes }) if disallowed_attributes.any?

    scoped_transactions.update_all(attributes)
  end

  private

  def disallowed_attributes
    attributes.keys.map(&:to_s) - ALLOWED_ATTRIBUTES
  end
end

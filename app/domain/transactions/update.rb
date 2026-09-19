class Transactions::Update
  include Interactor::Initializer

  COUNTERPARTY_KEYS = %i[counterparty_id counterparty_options].freeze

  initialize_with_keyword_params :transaction, :attributes

  def run
    transaction.update!(own_attributes.merge(counterparty_attribute))
    transaction
  end

  private

  def own_attributes
    attributes.except(*COUNTERPARTY_KEYS)
  end

  def counterparty_attribute
    counterparty_supplied? ? { counterparty: counterparty } : {}
  end

  def counterparty_supplied?
    COUNTERPARTY_KEYS.any? { |key| attributes[key].present? }
  end

  def counterparty
    attributes[:counterparty_id] ? User.find(attributes[:counterparty_id]) : Users::ResolveCounterparty.for(attributes[:counterparty_options])
  end
end

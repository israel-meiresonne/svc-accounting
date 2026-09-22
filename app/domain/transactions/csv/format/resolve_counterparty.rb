class Transactions::Csv::Format::ResolveCounterparty
  include Interactor::Initializer

  COUNTERPARTY_TYPES = %w[contact company].freeze
  COMPANY_SUFFIX_PATTERN = /\b(UAB|Ltd|GmbH|SA|AB|Inc|LLC|Bvba|Sprl)\.?\z/i
  EXTRACTION_PATTERN = /\A(?:To|From|Payment from)\s+(.+)\z/i

  initialize_with_keyword_params :user, :description

  def run
    { counterparty_name: counterparty_name, counterparty_type: counterparty_type }
  end

  private

  def counterparty_name
    existing_user&.display_name || extracted_name || ""
  end

  def counterparty_type
    return existing_user.type if existing_user
    return "" if extracted_name.blank?

    company_suffix?(extracted_name) ? "company" : "contact"
  end

  def existing_user
    return @existing_user if defined?(@existing_user)

    @existing_user = searchable_users.find { |candidate| name_mentioned_in_description?(candidate) }
  end

  def searchable_users
    User.where(type: COUNTERPARTY_TYPES).or(User.where(id: transacted_counterparty_ids))
  end

  def transacted_counterparty_ids
    user.accounts.joins(:transactions).select("transactions.counterparty_id")
  end

  def name_mentioned_in_description?(candidate)
    normalized_description = description.downcase

    if candidate.company_type?
      normalized_description.include?(candidate.company_name.downcase)
    else
      normalized_description.include?(candidate.first_name.downcase) &&
        normalized_description.include?(candidate.last_name.downcase)
    end
  end

  def extracted_name
    return @extracted_name if defined?(@extracted_name)

    @extracted_name = description[EXTRACTION_PATTERN, 1]
  end

  def company_suffix?(name)
    name.match?(COMPANY_SUFFIX_PATTERN)
  end
end

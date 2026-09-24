class Transactions::Csv::Format::FromRevolut
  include Interactor::Initializer

  EXPECTED_COLUMNS = [
    "Type",
    "Product",
    "Started Date",
    "Completed Date",
    "Description",
    "Amount",
    "Fee",
    "Currency",
    "State",
    "Balance"
  ].freeze

  DROPPED_STATES = %w[
    REVERTED
    PENDING
  ].freeze

  PAYMENT_METHOD_BY_TYPE = {
    "Card Payment" => "credit_card",
    "Card Refund" => "credit_card",
    "CARD_CREDIT" => "credit_card",
    "Card Chargeback" => "credit_card",
    "Rev Payment" => "credit_card",
    "ATM" => "cash",
    "Transfer" => "bank_transfer",
    "Deposit" => "bank_transfer",
    "Exchange" => "bank_transfer",
    "TRADE" => "bank_transfer",
    "Fee" => "bank_transfer",
    "Charge" => "bank_transfer"
  }.freeze

  KNOWN_ENTITIES = {
    "Revolut Bank UAB" => "Revolut Bank UAB",
    "Revolut Bank UAB Zweigniederlassung Deutschland" => "Revolut Bank UAB"
  }.freeze

  INTERNAL_TRANSFER_CATEGORY = "Transfers"

  # config/assets/transactions/csv_formatting/revolut_counterparties.yml
  COUNTERPARTY_OVERRIDES_PATH = Rails.root.join(
    "config",
    "assets",
    "transactions",
    "csv_formatting",
    "revolut_counterparties.yml"
  )

  initialize_with_keyword_params :user, :csv_rows

  def run
    validate_columns!

    kept_rows.each_with_index.flat_map { |row, index| format_row(row, index) }
  end

  private

  def validate_columns!
    missing = EXPECTED_COLUMNS - csv_rows.headers
    return if missing.empty?

    raise Transactions::Errors::InvalidCsvColumnsError.new(details: { missing: missing })
  end

  def kept_rows
    @kept_rows ||= csv_rows.reject { |row| DROPPED_STATES.include?(row["State"]) }
  end

  def format_row(row, index)
    build_output_rows(row, classification_for(row, index))
  end

  def build_output_rows(row, classification)
    split_amounts(row).map { |amount| build_output_row(row, amount, classification) }
  end

  def build_output_row(row, amount, classification)
    {
      occurred_at: row["Completed Date"],
      amount: amount,
      currency: row["Currency"],
      payment_method: payment_method_for(row),
      category: classification[:category],
      description: row["Description"],
      account: account_name(row),
      counterparty_type: classification[:counterparty_type],
      counterparty_name: classification[:counterparty_name],
      counterparty_email: ""
    }
  end

  def account_name(row)
    "Revolut #{row['Product']} #{row['Currency'].upcase}"
  end

  def payment_method_for(row)
    PAYMENT_METHOD_BY_TYPE.fetch(row["Type"]) { raise_unknown_type(row["Type"]) }
  end

  def raise_unknown_type(type)
    raise Transactions::Errors::InvalidCsvColumnsError.new(details: { unknown_type: type })
  end

  def split_amounts(row)
    return [ row["Amount"] ] unless fee_present?(row)
    return [ negated_fee(row) ] if row["Type"] == "Charge"

    [ row["Amount"], negated_fee(row) ]
  end

  def fee_present?(row)
    row["Fee"] != "0.00"
  end

  def negated_fee(row)
    format("%.2f", -row["Fee"].to_f)
  end

  def classification_for(row, index)
    return transfer_classification(row) if internal_transfer?(row, index)

    external_classification(row)
  end

  def transfer_classification(row)
    transfer_counterparty(row).merge(category: INTERNAL_TRANSFER_CATEGORY)
  end

  def transfer_counterparty(row)
    known_name = KNOWN_ENTITIES[row["Description"]]
    return known_entity_counterparty(known_name) if known_name

    { counterparty_name: user.display_name, counterparty_type: user.type }
  end

  def known_entity_counterparty(name)
    existing = existing_user_for_canonical_name(name)

    { counterparty_name: name, counterparty_type: existing&.type || "company" }
  end

  def external_classification(row)
    resolved = resolved_counterparty(row)

    {
      category: assign_category(row, resolved[:counterparty_name]) || "",
      counterparty_name: resolved[:counterparty_name],
      counterparty_type: resolved[:counterparty_type]
    }
  end

  def resolved_counterparty(row)
    override = override_for(row)
    return override if override

    resolved = resolve_counterparty(row)
    return resolved if resolved[:counterparty_name].present?

    default_counterparty(row)
  end

  def override_for(row)
    entry = counterparty_overrides.find { |candidate| row["Description"].downcase.include?(candidate["match"].downcase) }
    return unless entry

    existing = existing_user_for_canonical_name(entry["name"])

    { counterparty_name: entry["name"], counterparty_type: existing&.type || entry["type"] }
  end

  def existing_user_for_canonical_name(name)
    User.find { |candidate| candidate.display_name.strip.downcase == name.downcase }
  end

  def default_counterparty(row)
    { counterparty_name: row["Description"].to_s.strip.squeeze(" "), counterparty_type: "company" }
  end

  def counterparty_overrides
    @counterparty_overrides ||= YAML.load_file(COUNTERPARTY_OVERRIDES_PATH)
  end

  def resolve_counterparty(row)
    Transactions::Csv::Format::ResolveCounterparty.for(user: user, description: row["Description"])
  end

  def assign_category(row, counterparty_name)
    Transactions::Csv::Format::AssignCategory.for(user: user, description: row["Description"], counterparty_name: counterparty_name)
  end

  def internal_transfer?(row, index)
    row["Type"] == "Exchange" || internal_transfer_indices.include?(index) || KNOWN_ENTITIES.key?(row["Description"])
  end

  def internal_transfer_indices
    @internal_transfer_indices ||= compute_internal_transfer_indices
  end

  def compute_internal_transfer_indices
    indexed_rows = kept_rows.each_with_index.to_a

    indexed_rows.each_with_object(Set.new) do |(row, index), indices|
      indices << index if paired?(row, index, indexed_rows)
    end
  end

  def paired?(row, index, indexed_rows)
    indexed_rows.any? do |other_row, other_index|
      other_index != index && same_group?(row, other_row) && amounts_cancel?(row, other_row)
    end
  end

  def same_group?(row, other_row)
    row["Started Date"] == other_row["Started Date"] && row["Currency"] == other_row["Currency"]
  end

  def amounts_cancel?(row, other_row)
    row["Amount"].to_f != 0.0 && row["Amount"].to_f == -other_row["Amount"].to_f
  end
end

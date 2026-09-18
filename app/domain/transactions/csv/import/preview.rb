class Transactions::Csv::Import::Preview
  include Interactor::Initializer
  include Transactions::Csv::Import::FieldMapping

  initialize_with_keyword_params :user_account, :rows

  def run
    rows.map { |row| preview_row(row) }
  end

  private

  def preview_row(row)
    account = find_account(row)
    return invalid(row, [ "Account not found" ]) unless account

    candidate = build_candidate(account, row)
    return invalid(row, candidate.errors.full_messages) unless candidate.valid?

    preview_result(row: row, candidate: candidate, existing: find_existing_duplicate(account, candidate))
  end

  def find_account(row)
    user_account.find_by(code: row[:account_code])
  end

  def find_existing_duplicate(account, candidate)
    Transaction.active.find_by(account: account, dedup_hash: candidate.dedup_hash)
  end

  def preview_result(row:, candidate:, existing:)
    {
      row: row,
      counterparty_code: candidate.counterparty.code,
      dedup_hash: candidate.dedup_hash,
      status: existing ? "duplicate" : "ok",
      duplicate_group_id: existing ? candidate.dedup_hash : nil
    }
  end

  def build_candidate(account, row)
    account.transactions.build(csv_row_attributes(row).merge(counterparty_id: resolved_counterparty(row).id))
  end

  def resolved_counterparty(row)
    Users::ResolveCounterparty.for(counterparty_options(row))
  end

  def counterparty_options(row)
    {
      type: row[:counterparty_type],
      first_name: row[:counterparty_first_name],
      last_name: row[:counterparty_last_name],
      company_name: row[:counterparty_company_name],
      email: row[:counterparty_email]
    }
  end

  def invalid(row, errors)
    { row: row, status: "invalid", errors: errors }
  end
end

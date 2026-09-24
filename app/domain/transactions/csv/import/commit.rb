class Transactions::Csv::Import::Commit
  include Interactor::Initializer
  include Transactions::Csv::Import::FieldMapping

  initialize_with_keyword_params :user_account, :rows

  def run
    { imported_count: commit_all_rows }
  end

  private

  def commit_all_rows
    ActiveRecord::Base.transaction do
      committed_accounts = rows.map { |row| commit_row(row) }.compact
      resolve_balances(committed_accounts.uniq)
      committed_accounts.size
    end
  end

  def resolve_balances(accounts)
    accounts.each { |account| resolve_balance_for(account) }
  end

  def resolve_balance_for(account)
    Accounts::ResolveBalanceAtCreation.for(account)
  end

  def commit_row(row)
    case row[:resolution]
    when "drop" then nil
    when "overwrite" then overwrite_existing(row)
    else create_transaction(row)
    end
  end

  def create_transaction(row)
    account = find_account!(row)
    account.transactions.create!(transaction_attributes(row))
    account
  end

  def overwrite_existing(row)
    account = find_account!(row)
    existing_transaction(account, row).update!(transaction_attributes(row))
    account
  end

  def find_account!(row)
    user_account.find_by!(code: row[:account_code])
  end

  def existing_transaction(account, row)
    account.transactions.active.find_by!(dedup_hash: row[:dedup_hash])
  end

  def transaction_attributes(row)
    csv_row_attributes(row).merge(counterparty: resolved_counterparty(row))
  end

  def resolved_counterparty(row)
    User.find_by!(code: row[:counterparty_code])
  end
end

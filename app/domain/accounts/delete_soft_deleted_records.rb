class Accounts::DeleteSoftDeletedRecords
  include Interactor::Initializer

  def run
    stale_accounts.find_each { |account| delete_account(account) }
  end

  private

  def stale_accounts
    Account.where(deleted_at: ..cutoff)
  end

  def cutoff
    SoftDeletable::RETENTION_PERIOD.ago
  end

  def delete_account(account)
    account.transactions.delete_all(:delete_all)
    account.delete
  end
end

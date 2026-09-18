class Transactions::DeleteSoftDeletedRecords
  include Interactor::Initializer

  def run
    stale_transactions.delete_all
  end

  private

  def stale_transactions
    Transaction.where(deleted_at: ..cutoff)
  end

  def cutoff
    SoftDeletable::RETENTION_PERIOD.ago
  end
end

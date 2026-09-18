namespace :transactions do
  desc "Permanently delete transactions soft-deleted past SoftDeletable::RETENTION_PERIOD"
  task delete_soft_deleted: :environment do
    Transactions::DeleteSoftDeletedRecords.run
  end
end

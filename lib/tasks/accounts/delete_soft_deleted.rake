namespace :accounts do
  desc "Permanently delete accounts soft-deleted past SoftDeletable::RETENTION_PERIOD"
  task delete_soft_deleted: :environment do
    Accounts::DeleteSoftDeletedRecords.run
  end
end

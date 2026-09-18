require "rails_helper"

RSpec.describe Transactions::DeleteSoftDeletedRecords, type: :interactor do
  subject { described_class.run }

  around { |example| Timecop.freeze(Time.zone.local(2026, 6, 15, 12, 0, 0)) { example.run } }

  let!(:active_transaction) { create(:transaction) }
  let!(:recently_deleted_transaction) { create(:transaction, deleted_at: SoftDeletable::RETENTION_PERIOD.ago + 1.day) }
  let!(:stale_transaction) { create(:transaction, deleted_at: SoftDeletable::RETENTION_PERIOD.ago - 1.day) }
  let!(:deleted_account) { create(:account, deleted_at: Time.current) }
  let!(:stale_transaction_on_deleted_account) do
    create(:transaction, account: deleted_account, deleted_at: SoftDeletable::RETENTION_PERIOD.ago - 1.day)
  end

  it "deletes transactions soft-deleted past the retention period" do
    subject

    expect(Transaction.where(id: stale_transaction.id)).to be_empty
  end

  it "keeps transactions soft-deleted within the retention period" do
    subject

    expect(Transaction.where(id: recently_deleted_transaction.id)).to exist
  end

  it "keeps active transactions" do
    subject

    expect(Transaction.where(id: active_transaction.id)).to exist
  end

  it "deletes a stale transaction regardless of its account's own soft-delete state" do
    subject

    expect(Transaction.where(id: stale_transaction_on_deleted_account.id)).to be_empty
  end
end

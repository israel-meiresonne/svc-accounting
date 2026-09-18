require "rails_helper"

RSpec.describe Accounts::DeleteSoftDeletedRecords, type: :interactor do
  subject { described_class.run }

  around { |example| Timecop.freeze(Time.zone.local(2026, 6, 15, 12, 0, 0)) { example.run } }

  let!(:active_account) { create(:account) }
  let!(:recently_deleted_account) { create(:account, deleted_at: SoftDeletable::RETENTION_PERIOD.ago + 1.day) }
  let!(:stale_account) { create(:account, deleted_at: SoftDeletable::RETENTION_PERIOD.ago - 1.day) }
  let!(:stale_account_transaction) { create(:transaction, account: stale_account) }

  it "deletes accounts soft-deleted past the retention period" do
    subject

    expect(Account.where(id: stale_account.id)).to be_empty
  end

  it "keeps accounts soft-deleted within the retention period" do
    subject

    expect(Account.where(id: recently_deleted_account.id)).to exist
  end

  it "keeps active accounts" do
    subject

    expect(Account.where(id: active_account.id)).to exist
  end

  it "deletes a stale account's remaining transactions too" do
    subject

    expect(Transaction.where(id: stale_account_transaction.id)).to be_empty
  end
end

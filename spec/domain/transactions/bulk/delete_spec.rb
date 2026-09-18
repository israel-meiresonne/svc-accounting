require "rails_helper"

RSpec.describe Transactions::Bulk::Delete, type: :interactor do
  subject { described_class.for(**params) }

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let!(:transaction) { create(:transaction, account: account) }
  let(:params) { { user: user, transaction_codes: [ transaction.code ] } }

  it "soft-deletes the matching transactions" do
    subject

    expect(transaction.reload.deleted_at).to be_present
  end

  it "returns the number of deleted transactions" do
    expect(subject).to eq(1)
  end

  it "makes the transaction disappear from the active scope" do
    subject

    expect(Transaction.active).not_to include(transaction)
  end

  context "when the transaction belongs to another user" do
    let(:other_user) { create(:user) }
    let(:other_account) { create(:account, user: other_user) }
    let!(:other_transaction) { create(:transaction, account: other_account) }
    let(:params) { { user: user, transaction_codes: [ other_transaction.code ] } }

    it "affects zero rows" do
      expect(subject).to eq(0)
    end

    it "does not soft-delete the other user's transaction" do
      expect { subject }.not_to change { other_transaction.reload.deleted_at }
    end
  end
end

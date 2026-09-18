require "rails_helper"

RSpec.describe Transactions::Bulk::Move, type: :interactor do
  subject { described_class.for(**params) }

  let(:user) { create(:user) }
  let(:source_account) { create(:account, user: user, currency: "usd") }
  let(:destination_account) { create(:account, user: user, currency: "usd") }
  let!(:transaction) { create(:transaction, account: source_account, currency: "usd") }
  let(:params) { { user: user, transaction_codes: [ transaction.code ], destination_account_code: destination_account.code } }

  it "moves the matching transactions to the destination account" do
    subject

    expect(transaction.reload.account).to eq(destination_account)
  end

  it "returns the number of moved transactions" do
    expect(subject).to eq(1)
  end

  context "when a selected transaction's currency does not match the destination account's currency" do
    let(:destination_account) { create(:account, user: user, currency: "eur") }

    it "raises Transactions::Errors::CurrencyMismatchError" do
      expect { subject }.to raise_error(Transactions::Errors::CurrencyMismatchError)
    end

    it "carries the destination currency and the mismatched currencies in the error details" do
      expect { subject }.to raise_error(having_attributes(details: { destination_currency: "eur", mismatched_currencies: [ "usd" ] }))
    end

    it "moves nothing" do
      expect { subject }.to raise_error(Transactions::Errors::CurrencyMismatchError)
      expect(transaction.reload.account).to eq(source_account)
    end
  end

  context "when the destination account does not belong to the current user" do
    let(:other_user) { create(:user) }
    let(:destination_account) { create(:account, user: other_user, currency: "usd") }

    it "raises ActiveRecord::RecordNotFound" do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "when the transaction belongs to another user" do
    let(:other_user) { create(:user) }
    let(:other_account) { create(:account, user: other_user, currency: "usd") }
    let!(:other_transaction) { create(:transaction, account: other_account, currency: "usd") }
    let(:params) { { user: user, transaction_codes: [ other_transaction.code ], destination_account_code: destination_account.code } }

    it "affects zero rows" do
      expect(subject).to eq(0)
    end

    it "does not move the other user's transaction" do
      expect { subject }.not_to change { other_transaction.reload.account }
    end
  end
end

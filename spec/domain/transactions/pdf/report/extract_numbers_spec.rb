require "rails_helper"

RSpec.describe Transactions::Pdf::Report::ExtractNumbers, type: :interactor do
  subject { described_class.for(**params) }

  let(:account) { create(:account, currency: "usd") }
  let!(:first_transaction) { create(:transaction, account: account, amount: 100, currency: "usd") }
  let!(:second_transaction) { create(:transaction, account: account, amount: -30, currency: "usd") }
  let(:params) { { transactions: [ first_transaction, second_transaction ], reporting_currency: "usd" } }

  context "when every transaction is already in the reporting currency" do
    it "sums the transactions' amounts without converting" do
      expect(subject.as_json).to eq(amount: "70.00", currency: "usd")
    end
  end

  context "when a transaction is in a different currency" do
    let(:eur_account) { create(:account, currency: "eur") }
    let!(:eur_transaction) { create(:transaction, account: eur_account, amount: 40, currency: "eur") }
    let(:params) { { transactions: [ first_transaction, eur_transaction ], reporting_currency: "usd" } }

    let!(:usd_to_eur) { create(:currency_rate, left: "usd", right: "eur", rate: 0.5) }

    it "normalizes every transaction into the reporting currency before summing" do
      expect(subject.as_json).to eq(amount: "180.00", currency: "usd")
    end
  end

  context "when the selection is empty" do
    let(:params) { { transactions: [], reporting_currency: "usd" } }

    it "returns a zero-amount money value in the reporting currency" do
      expect(subject.as_json).to eq(amount: "0.00", currency: "usd")
    end
  end
end

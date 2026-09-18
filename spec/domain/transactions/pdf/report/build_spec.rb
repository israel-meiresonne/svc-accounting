require "rails_helper"

RSpec.describe Transactions::Pdf::Report::Build, type: :interactor do
  subject { described_class.for(**params) }

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, currency: "usd") }
  let!(:transaction) { create(:transaction, account: account, currency: "usd") }
  let(:params) do
    { user: user, transaction_codes: [ transaction.code ], title: "Q2 report", description: "Quarterly summary", reporting_currency: "usd" }
  end

  it "returns a non-empty PDF document" do
    expect(subject).to be_a(String)
    expect(subject).to start_with("%PDF-")
  end

  context "when the selection is empty" do
    let(:params) { { user: user, transaction_codes: [], title: "Q2 report", description: "Quarterly summary", reporting_currency: "usd" } }

    it "raises Transactions::Errors::EmptySelectionError" do
      expect { subject }.to raise_error(Transactions::Errors::EmptySelectionError)
    end
  end

  context "when every transaction code belongs to another user" do
    let(:other_user) { create(:user) }
    let(:other_account) { create(:account, user: other_user, currency: "usd") }
    let!(:other_transaction) { create(:transaction, account: other_account, currency: "usd") }
    let(:params) do
      { user: user, transaction_codes: [ other_transaction.code ], title: "Q2 report", description: "Quarterly summary", reporting_currency: "usd" }
    end

    it "raises Transactions::Errors::EmptySelectionError rather than including the other user's transaction" do
      expect { subject }.to raise_error(Transactions::Errors::EmptySelectionError)
    end
  end
end

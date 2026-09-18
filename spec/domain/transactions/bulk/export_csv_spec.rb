require "rails_helper"

RSpec.describe Transactions::Bulk::ExportCsv, type: :interactor do
  subject { described_class.for(**params) }

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, name: "Checking") }
  let(:counterparty) { create(:contact, first_name: "John", last_name: "Doe") }
  let!(:transaction) do
    create(
      :transaction,
      account: account,
      counterparty: counterparty,
      amount: 42,
      currency: "usd",
      category: "food",
      payment_method: "cash",
      description: "lunch",
      occurred_at: Time.zone.local(2026, 6, 15, 12, 0, 0),
    )
  end
  let(:params) { { user: user, transaction_codes: [ transaction.code ] } }

  it "writes the header row" do
    expect(subject.lines.first.strip).to eq("date,amount,currency,category,payment_method,counterparty,description,account")
  end

  it "writes one row per transaction with the right column values, in order" do
    expect(subject.lines.second.strip).to eq("2026-06-15,42.0,usd,food,cash,John Doe,lunch,Checking")
  end

  context "when a cell would start with a formula-injection character" do
    let!(:transaction) do
      create(:transaction, account: account, counterparty: counterparty, category: "=cmd", description: "+1", occurred_at: Time.current)
    end

    it "prefixes the dangerous cell with a quote" do
      expect(subject.lines.second.strip).to include("'=cmd")
      expect(subject.lines.second.strip).to include("'+1")
    end
  end

  context "when the selection is empty" do
    let(:params) { { user: user, transaction_codes: [] } }

    it "produces a header-only CSV" do
      expect(subject.lines.map(&:strip)).to eq([ "date,amount,currency,category,payment_method,counterparty,description,account" ])
    end
  end

  context "when a transaction code belongs to another user" do
    let(:other_user) { create(:user) }
    let(:other_account) { create(:account, user: other_user) }
    let!(:other_transaction) { create(:transaction, account: other_account) }
    let(:params) { { user: user, transaction_codes: [ other_transaction.code ] } }

    it "produces a header-only CSV, affecting zero rows" do
      expect(subject.lines.map(&:strip)).to eq([ "date,amount,currency,category,payment_method,counterparty,description,account" ])
    end
  end
end

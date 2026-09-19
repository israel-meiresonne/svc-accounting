require "rails_helper"

RSpec.describe Transactions::Update, type: :interactor do
  subject { described_class.for(**params) }

  let!(:account) { create(:account, currency: "usd") }
  let!(:counterparty) { create(:contact, first_name: "Original", last_name: "Contact") }
  let!(:transaction) do
    create(:transaction, account: account, counterparty: counterparty, amount: 50, category: "food", description: "old")
  end
  let(:params) { { transaction: transaction, attributes: attributes } }
  let(:attributes) { { amount: 75, category: "rent", description: "new" } }

  it "updates the supplied attributes" do
    subject

    expect(transaction.reload).to have_attributes(amount: 75, category: "rent", description: "new")
  end

  it "returns the updated transaction" do
    expect(subject).to eq(transaction)
  end

  it "leaves the counterparty untouched when no counterparty params are supplied" do
    expect { subject }.not_to change { transaction.reload.counterparty_id }
  end

  context "when a counterparty_id is supplied" do
    let!(:other_counterparty) { create(:contact, first_name: "New", last_name: "Contact") }
    let(:attributes) { { category: "rent", counterparty_id: other_counterparty.id } }

    it "re-resolves the counterparty to the supplied record" do
      subject

      expect(transaction.reload.counterparty).to eq(other_counterparty)
    end
  end

  context "when counterparty_options are supplied" do
    let(:attributes) { { category: "rent", counterparty_options: { type: "company", company_name: "Acme Inc" } } }

    it "resolves a new counterparty through Users::ResolveCounterparty" do
      subject

      expect(transaction.reload.counterparty).to have_attributes(type: "company", company_name: "Acme Inc")
    end

    it "creates the counterparty record" do
      expect { subject }.to change { User.where(type: "company").count }.by(1)
    end
  end

  context "when counterparty keys are present but blank" do
    let(:attributes) { { category: "rent", counterparty_id: nil, counterparty_options: nil } }

    it "keeps the existing counterparty" do
      expect { subject }.not_to change { transaction.reload.counterparty_id }
    end

    it "still updates the other attributes" do
      subject

      expect(transaction.reload.category).to eq("rent")
    end
  end

  context "when the attributes are invalid" do
    let(:attributes) { { occurred_at: nil } }

    it "raises ActiveRecord::RecordInvalid" do
      expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

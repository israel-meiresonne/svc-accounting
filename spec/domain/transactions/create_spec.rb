require "rails_helper"

RSpec.describe Transactions::Create, type: :interactor do
  subject { described_class.for(**params) }

  let!(:account) { create(:account, currency: "usd", initial_balance: 100) }
  let!(:counterparty) { create(:contact) }
  let(:params) do
    {
      account: account,
      amount: 50,
      category: "groceries",
      description: "Weekly shop",
      payment_method: "cash",
      occurred_at: "2026-01-05T10:00:00Z",
      counterparty_id: counterparty.id,
      counterparty_options: nil
    }
  end

  it "persists a transaction on the account" do
    expect { subject }.to change { account.transactions.count }.by(1)
  end

  it "returns the created transaction with the supplied attributes" do
    expect(subject).to have_attributes(amount: 50, category: "groceries", description: "Weekly shop", payment_method: "cash")
  end

  it "reads the currency from the account instead of accepting one" do
    expect(subject.currency).to eq("usd")
  end

  it "assigns the counterparty found by id" do
    expect(subject.counterparty).to eq(counterparty)
  end

  context "when counterparty_options are supplied instead of an id" do
    let(:params) do
      {
        account: account,
        amount: -20,
        category: "rent",
        description: nil,
        payment_method: "bank_transfer",
        occurred_at: "2026-01-05T10:00:00Z",
        counterparty_id: nil,
        counterparty_options: { type: "company", company_name: "Acme Inc" }
      }
    end

    it "resolves the counterparty through Users::ResolveCounterparty" do
      expect(subject.counterparty).to have_attributes(type: "company", company_name: "Acme Inc")
    end

    it "creates the counterparty record" do
      expect { subject }.to change { User.where(type: "company").count }.by(1)
    end
  end

  context "when the account is in current-balance mode" do
    let!(:account) { create(:account, currency: "usd", initial_balance: 500, balance_at_creation: 500) }

    it "back-derives the account's initial balance" do
      subject

      expect(account.reload.initial_balance).to eq(450)
    end

    it "clears balance_at_creation" do
      subject

      expect(account.reload.balance_at_creation).to be_nil
    end
  end

  context "when the account is not in current-balance mode" do
    it "leaves the account's initial balance untouched" do
      expect { subject }.not_to change { account.reload.initial_balance }
    end
  end

  context "when neither counterparty_id nor counterparty_options is supplied" do
    let(:params) do
      {
        account: account,
        amount: 50,
        category: "groceries",
        description: "Weekly shop",
        payment_method: "cash",
        occurred_at: "2026-01-05T10:00:00Z",
        counterparty_id: nil,
        counterparty_options: nil
      }
    end

    it "raises Transactions::Errors::MissingCounterpartyError" do
      expect { subject }.to raise_error(Transactions::Errors::MissingCounterpartyError)
    end
  end

  context "when a required attribute is missing" do
    let(:params) do
      {
        account: account,
        amount: 50,
        category: "groceries",
        description: nil,
        payment_method: "cash",
        occurred_at: nil,
        counterparty_id: counterparty.id,
        counterparty_options: nil
      }
    end

    it "raises ActiveRecord::RecordInvalid" do
      expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

require "rails_helper"

RSpec.describe Transactions::Csv::Format::AssignCategory, type: :interactor do
  subject { described_class.for(user: user, description: description, counterparty_name: counterparty_name) }

  let!(:user) { create(:user) }
  let!(:account) { create(:account, user: user) }
  let(:description) { "Coffee Shop" }
  let(:counterparty_name) { "John Contact" }

  context "when a prior transaction matches both description and counterparty" do
    let!(:counterparty) { create(:contact, first_name: "John", last_name: "Contact") }
    let!(:transaction) do
      create(:transaction, account: account, counterparty: counterparty, description: "Coffee Shop", category: "Food")
    end

    it "returns that transaction's category" do
      expect(subject).to eq("Food")
    end
  end

  context "when a prior transaction matches the description but not the counterparty" do
    let!(:other_counterparty) { create(:contact, first_name: "Jane", last_name: "Stranger") }
    let!(:transaction) do
      create(:transaction, account: account, counterparty: other_counterparty, description: "Coffee Shop", category: "Food")
    end

    it "returns nil" do
      expect(subject).to be_nil
    end
  end

  context "when no counterparty name was resolved" do
    let(:counterparty_name) { "" }

    it "returns nil without querying for a matching transaction" do
      expect(Transaction).not_to receive(:joins)

      expect(subject).to be_nil
    end
  end

  context "when multiple prior transactions match both description and counterparty" do
    let!(:counterparty) { create(:contact, first_name: "John", last_name: "Contact") }
    let!(:older_transaction) do
      create(:transaction, account: account, counterparty: counterparty, description: "Coffee Shop", category: "Old",
                            occurred_at: 2.days.ago)
    end
    let!(:newer_transaction) do
      create(:transaction, account: account, counterparty: counterparty, description: "Coffee Shop", category: "New",
                            occurred_at: 1.hour.ago)
    end

    it "returns the most recent matching transaction's category" do
      expect(subject).to eq("New")
    end
  end
end

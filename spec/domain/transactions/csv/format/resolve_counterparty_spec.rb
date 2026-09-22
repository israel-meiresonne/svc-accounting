require "rails_helper"

RSpec.describe Transactions::Csv::Format::ResolveCounterparty, type: :interactor do
  subject { described_class.for(user: user, description: description) }

  let!(:user) { create(:user) }

  context "when an existing contact's full name is mentioned in the description" do
    let(:description) { "To Egidijus Bulevičius" }
    let!(:contact) { create(:contact, first_name: "Egidijus", last_name: "Bulevičius") }

    it "resolves the contact's display name and type" do
      expect(subject).to eq(counterparty_name: "Egidijus Bulevičius", counterparty_type: "contact")
    end
  end

  context "when an existing company's name is mentioned in the description" do
    let(:description) { "Payment from Acme Corp UAB" }
    let!(:company) { create(:company, company_name: "Acme Corp UAB") }

    it "resolves the company's display name and type" do
      expect(subject).to eq(counterparty_name: "Acme Corp UAB", counterparty_type: "company")
    end
  end

  context "when only the contact's first name is mentioned, not the last name" do
    let(:description) { "To Egidijus" }
    let!(:contact) { create(:contact, first_name: "Egidijus", last_name: "Bulevičius") }

    it "does not match that contact" do
      expect(subject).to eq(counterparty_name: "Egidijus", counterparty_type: "contact")
    end
  end

  context "when a plain user has already transacted with the acting user" do
    let(:description) { "To Bob Transacted" }
    let!(:counterparty) { create(:user, first_name: "Bob", last_name: "Transacted") }
    let!(:account) { create(:account, user: user) }
    let!(:transaction) { create(:transaction, account: account, counterparty: counterparty) }

    it "resolves that user as the counterparty" do
      expect(subject).to eq(counterparty_name: "Bob Transacted", counterparty_type: "user")
    end
  end

  context "when a plain user's name is mentioned but has never transacted with the acting user" do
    let(:description) { "To Carol Stranger" }
    let!(:stranger) { create(:user, first_name: "Carol", last_name: "Stranger") }

    it "does not match that user and falls back to the To <name> extraction" do
      expect(subject).to eq(counterparty_name: "Carol Stranger", counterparty_type: "contact")
    end
  end

  context "when no existing user matches and the description has a To <name> pattern" do
    let(:description) { "To Alice Wonderland" }

    it "extracts the name and resolves counterparty_type as contact" do
      expect(subject).to eq(counterparty_name: "Alice Wonderland", counterparty_type: "contact")
    end
  end

  context "when no existing user matches and the extracted name has a company suffix" do
    let(:description) { "To Acme UAB" }

    it "resolves counterparty_type as company" do
      expect(subject).to eq(counterparty_name: "Acme UAB", counterparty_type: "company")
    end
  end

  context "when no existing user matches and no pattern is extractable" do
    let(:description) { "Card Payment XYZ" }

    it "returns blank for both counterparty_name and counterparty_type" do
      expect(subject).to eq(counterparty_name: "", counterparty_type: "")
    end
  end
end

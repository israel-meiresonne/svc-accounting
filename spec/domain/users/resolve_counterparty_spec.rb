require "rails_helper"

RSpec.describe Users::ResolveCounterparty, type: :interactor do
  subject { described_class.for(options) }

  context "when an existing user matches the given email" do
    let(:options) { { type: "contact", first_name: "New", last_name: "Name", email: "jane@example.com" } }
    let!(:existing_user) { create(:user, email: "jane@example.com") }

    it "resolves to the existing user" do
      expect(subject).to eq(existing_user)
    end

    it "does not create a new user" do
      expect { subject }.not_to change(User, :count)
    end
  end

  context "when no email is given and the counterparty is a contact" do
    let(:options) { { type: "contact", first_name: "John", last_name: "Contact", email: nil } }

    it "creates a new contact" do
      expect(subject).to be_contact_type
    end

    it "persists a new user" do
      expect { subject }.to change(User, :count).by(1)
    end
  end

  context "when no email is given and the counterparty is a company" do
    let(:options) { { type: "company", company_name: "Acme Inc", email: nil } }

    it "creates a new company" do
      expect(subject).to be_company_type
    end

    it "persists a new user" do
      expect { subject }.to change(User, :count).by(1)
    end
  end
end

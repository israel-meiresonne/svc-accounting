require "rails_helper"

RSpec.describe User, type: :model do
  context "with factory" do
    it "creates a valid user" do
      expect(build(:user)).to be_valid
    end

    it "creates a valid contact" do
      expect(build(:contact)).to be_valid
    end

    it "creates a valid company" do
      expect(build(:company)).to be_valid
    end

    it "assigns a usr_-prefixed code on create" do
      expect(create(:user).code).to match(/\Ausr_[0-9A-Z]{26}\z/)
    end

    it "returns the company name as display_name for a company" do
      expect(build(:company, company_name: "Acme Inc").display_name).to eq("Acme Inc")
    end

    it "returns the first and last name as display_name for a user" do
      expect(build(:user, first_name: "Jane", last_name: "Doe").display_name).to eq("Jane Doe")
    end
  end

  context "with associations" do
    it "has many accounts" do
      user = create(:user)
      account = create(:account, user: user)

      expect(user.accounts).to contain_exactly(account)
    end

    it "has many counterparty_transactions" do
      counterparty = create(:contact)
      transaction = create(:transaction, counterparty: counterparty)

      expect(counterparty.counterparty_transactions).to contain_exactly(transaction)
    end
  end

  context "with validations" do
    context "when type is user" do
      it "requires an email" do
        user = build(:user, email: nil)

        expect(user).not_to be_valid
      end

      it "requires a password" do
        user = build(:user, password: nil, password_confirmation: nil)

        expect(user).not_to be_valid
      end

      it "requires a lowercase three-letter currency" do
        user = build(:user, currency: "USD")

        expect(user).not_to be_valid
      end

      it "requires a first and last name" do
        user = build(:user, first_name: nil, last_name: nil)

        expect(user).not_to be_valid
      end

      it "does not require a company_name" do
        expect(build(:user, company_name: nil)).to be_valid
      end
    end

    context "when type is contact" do
      it "does not require an email" do
        expect(build(:contact, email: nil)).to be_valid
      end

      it "does not require a password" do
        expect(build(:contact, password: nil)).to be_valid
      end

      it "does not require a currency" do
        expect(build(:contact, currency: nil)).to be_valid
      end

      it "requires a first and last name" do
        contact = build(:contact, first_name: nil, last_name: nil)

        expect(contact).not_to be_valid
      end
    end

    context "when type is company" do
      it "does not require an email" do
        expect(build(:company, email: nil)).to be_valid
      end

      it "does not require a first or last name" do
        expect(build(:company, first_name: nil, last_name: nil)).to be_valid
      end

      it "requires a company_name" do
        company = build(:company, company_name: nil)

        expect(company).not_to be_valid
      end
    end

    it "requires type to be one of the known values" do
      user = build(:user, type: "unknown")

      expect(user).not_to be_valid
    end

    it "requires a unique email" do
      create(:user, email: "duplicate@example.com")
      user = build(:user, email: "duplicate@example.com")

      expect(user).not_to be_valid
    end
  end
end

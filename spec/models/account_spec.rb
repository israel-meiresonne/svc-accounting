require "rails_helper"

RSpec.describe Account, type: :model do
  context "with factory" do
    it "creates a valid account" do
      expect(build(:account)).to be_valid
    end

    it "assigns an acc_-prefixed code on create" do
      expect(create(:account).code).to match(/\Aacc_[0-9A-Z]{26}\z/)
    end
  end

  context "with associations" do
    it "belongs to a user" do
      user = create(:user)
      account = create(:account, user: user)

      expect(account.user).to eq(user)
    end

    it "has many transactions" do
      account = create(:account)
      transaction = create(:transaction, account: account)

      expect(account.transactions).to contain_exactly(transaction)
    end
  end

  context "with validations" do
    it "requires a name" do
      expect(build(:account, name: nil)).not_to be_valid
    end

    it "requires a lowercase three-letter currency" do
      expect(build(:account, currency: "USD")).not_to be_valid
    end
  end

  context "with #balance" do
    let!(:account) { create(:account, initial_balance: 100, currency: "usd") }
    let!(:income) { create(:transaction, account: account, amount: 50, currency: "usd") }
    let!(:expense) { create(:transaction, account: account, amount: -20, currency: "usd") }
    let!(:soft_deleted_transaction) do
      create(:transaction, account: account, amount: 1_000, currency: "usd", deleted_at: Time.current)
    end

    it "sums initial_balance and active transactions, excluding soft-deleted ones" do
      expect(account.balance.as_json).to eq(amount: "130.00", currency: "usd")
    end
  end

  context "with #has_transactions?" do
    let!(:account) { create(:account) }

    it "returns false when the account has no active transactions" do
      expect(account.has_transactions?).to be false
    end

    it "returns true when the account has an active transaction" do
      create(:transaction, account: account)

      expect(account.has_transactions?).to be true
    end

    it "returns false when the account's only transaction is soft-deleted" do
      create(:transaction, account: account, deleted_at: Time.current)

      expect(account.has_transactions?).to be false
    end
  end

  context "with #active_transactions_sum" do
    let!(:account) { create(:account, initial_balance: 100, currency: "usd") }
    let!(:income) { create(:transaction, account: account, amount: 50, currency: "usd") }
    let!(:expense) { create(:transaction, account: account, amount: -20, currency: "usd") }
    let!(:soft_deleted_transaction) do
      create(:transaction, account: account, amount: 1_000, currency: "usd", deleted_at: Time.current)
    end

    it "sums active transactions only, excluding soft-deleted ones" do
      expect(account.active_transactions_sum).to eq(30)
    end
  end
end

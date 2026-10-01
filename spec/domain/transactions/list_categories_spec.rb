require "rails_helper"

RSpec.describe Transactions::ListCategories, type: :interactor do
  subject { described_class.for(user) }

  let!(:user) { create(:user) }
  let!(:account) { create(:account, user: user) }

  context "when the user has categorized transactions" do
    let!(:rent) { create(:transaction, account: account, category: "Rent") }
    let!(:duplicate_rent) { create(:transaction, account: account, category: "Rent") }
    let!(:groceries) { create(:transaction, account: account, category: "Groceries") }
    let!(:transfers) { create(:transaction, account: account, category: "Transfers") }

    it "returns each distinct category once, sorted alphabetically" do
      expect(subject).to eq(%w[Groceries Rent Transfers])
    end
  end

  context "when another user has transactions with different categories" do
    let!(:own) { create(:transaction, account: account, category: "Rent") }
    let!(:other_account) { create(:account) }
    let!(:other) { create(:transaction, account: other_account, category: "Holidays") }

    it "returns only the user's own categories" do
      expect(subject).to eq(%w[Rent])
    end
  end

  context "when a transaction is soft-deleted" do
    let!(:kept) { create(:transaction, account: account, category: "Rent") }
    let!(:deleted) { create(:transaction, account: account, category: "Old", deleted_at: Time.current) }

    it "leaves its category out" do
      expect(subject).to eq(%w[Rent])
    end
  end

  context "when a transaction sits on a soft-deleted account" do
    let!(:kept) { create(:transaction, account: account, category: "Rent") }
    let!(:deleted_account) { create(:account, user: user, deleted_at: Time.current) }
    let!(:orphaned) { create(:transaction, account: deleted_account, category: "Closed") }

    it "leaves its category out" do
      expect(subject).to eq(%w[Rent])
    end
  end

  context "when some categories are nil or empty" do
    let!(:kept) { create(:transaction, account: account, category: "Rent") }
    let!(:without_category) { create(:transaction, account: account, category: nil) }
    let!(:empty_category) { create(:transaction, account: account, category: "") }

    it "leaves the blank ones out" do
      expect(subject).to eq(%w[Rent])
    end
  end

  context "when the user has no categorized transactions" do
    it "returns an empty array" do
      expect(subject).to eq([])
    end
  end
end

require "rails_helper"

RSpec.describe Transactions::CalculateStats, type: :interactor do
  subject { described_class.for(**params) }

  let!(:account) { create(:account, currency: "usd") }
  let!(:income_transaction) { create(:transaction, account: account, amount: 300, occurred_at: "2026-01-10T12:00:00Z") }
  let!(:expense_transaction) { create(:transaction, account: account, amount: -120, occurred_at: "2026-01-15T12:00:00Z") }
  let!(:out_of_range_transaction) { create(:transaction, account: account, amount: 999, occurred_at: "2026-02-10T12:00:00Z") }
  let(:params) { { account: account, from: "2026-01-01T00:00:00Z", to: "2026-01-31T23:59:59Z" } }

  it "sums the positive amounts into total_income" do
    expect(subject[:total_income].to_s).to eq("300.00")
  end

  it "sums the absolute negative amounts into total_expenses" do
    expect(subject[:total_expenses].to_s).to eq("120.00")
  end

  it "returns income minus expenses as net_balance" do
    expect(subject[:net_balance].to_s).to eq("180.00")
  end

  it "reports every figure in the account's currency" do
    expect(subject.values.map(&:currency)).to all(eq("usd"))
  end

  context "when a transaction in range is soft-deleted" do
    let!(:deleted_transaction) do
      create(:transaction, account: account, amount: 500, occurred_at: "2026-01-20T12:00:00Z", deleted_at: Time.current)
    end

    it "excludes it from total_income" do
      expect(subject[:total_income].to_s).to eq("300.00")
    end
  end

  context "when a transaction belongs to another account" do
    let!(:other_account) { create(:account, currency: "usd") }
    let!(:other_transaction) { create(:transaction, account: other_account, amount: 700, occurred_at: "2026-01-12T12:00:00Z") }

    it "excludes it from total_income" do
      expect(subject[:total_income].to_s).to eq("300.00")
    end
  end

  context "when the range ends on a February 29 in a leap year" do
    let!(:income_transaction) { create(:transaction, account: account, amount: 300, occurred_at: "2028-02-29T12:00:00Z") }
    let!(:expense_transaction) { create(:transaction, account: account, amount: -120, occurred_at: "2028-02-29T23:00:00Z") }
    let!(:out_of_range_transaction) { create(:transaction, account: account, amount: 999, occurred_at: "2028-03-01T00:00:01Z") }
    let(:params) { { account: account, from: "2028-02-01T00:00:00Z", to: "2028-02-29T23:59:59Z" } }

    it "includes the leap-day income" do
      expect(subject[:total_income].to_s).to eq("300.00")
    end

    it "includes the leap-day expense" do
      expect(subject[:total_expenses].to_s).to eq("120.00")
    end

    it "excludes the transaction that falls just after the leap day" do
      expect(subject[:net_balance].to_s).to eq("180.00")
    end
  end

  context "when the range holds no transactions" do
    let(:params) { { account: account, from: "2027-01-01T00:00:00Z", to: "2027-01-31T23:59:59Z" } }

    it "returns zeroed figures" do
      expect(subject.values.map(&:to_s)).to all(eq("0.00"))
    end
  end
end

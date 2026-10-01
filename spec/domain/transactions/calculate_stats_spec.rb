require "rails_helper"

RSpec.describe Transactions::CalculateStats, type: :interactor do
  subject { described_class.for(**params) }

  let!(:account) { create(:account, currency: "usd") }
  let!(:income_transaction) { create(:transaction, account: account, amount: 300, occurred_at: "2026-01-10T12:00:00Z") }
  let!(:expense_transaction) { create(:transaction, account: account, amount: -120, occurred_at: "2026-01-15T12:00:00Z") }
  let!(:out_of_range_transaction) { create(:transaction, account: account, amount: 999, occurred_at: "2026-02-10T12:00:00Z") }
  let(:params) { { account: account, from: "2026-01-01T00:00:00Z", to: "2026-01-31T23:59:59Z", included_categories: nil } }

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
    let(:params) { { account: account, from: "2028-02-01T00:00:00Z", to: "2028-02-29T23:59:59Z", included_categories: nil } }

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

  context "when included_categories is given" do
    let!(:income_transaction) { create(:transaction, account: account, amount: 300, category: "Salary", occurred_at: "2026-01-10T12:00:00Z") }
    let!(:expense_transaction) { create(:transaction, account: account, amount: -120, category: "Rent", occurred_at: "2026-01-15T12:00:00Z") }
    let!(:other_expense_transaction) { create(:transaction, account: account, amount: -50, category: "Transfers", occurred_at: "2026-01-16T12:00:00Z") }

    context "with one category" do
      let(:params) { super().merge(included_categories: [ "Rent" ]) }

      it "narrows total_income, total_expenses and net_balance to that category" do
        expect(subject.values.map(&:to_s)).to eq([ "0.00", "120.00", "-120.00" ])
      end
    end

    context "with several categories" do
      let(:params) { super().merge(included_categories: [ "Salary", "Rent" ]) }

      it "narrows all three figures to the union of those categories" do
        expect(subject.values.map(&:to_s)).to eq([ "300.00", "120.00", "180.00" ])
      end
    end

    context "with a category that matches nothing" do
      let(:params) { super().merge(included_categories: [ "Nope" ]) }

      it "returns zero for all three figures" do
        expect(subject.values.map(&:to_s)).to all(eq("0.00"))
      end
    end

    [ nil, [] ].each do |blank_value|
      context "with included_categories set to #{blank_value.inspect}" do
        let(:params) { super().merge(included_categories: blank_value) }

        it "applies no filter" do
          expect(subject.values.map(&:to_s)).to eq([ "300.00", "170.00", "130.00" ])
        end
      end
    end
  end

  context "when the range holds no transactions" do
    let(:params) { { account: account, from: "2027-01-01T00:00:00Z", to: "2027-01-31T23:59:59Z", included_categories: nil } }

    it "returns zeroed figures" do
      expect(subject.values.map(&:to_s)).to all(eq("0.00"))
    end
  end
end

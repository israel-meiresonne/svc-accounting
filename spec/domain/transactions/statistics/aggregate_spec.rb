require "rails_helper"

RSpec.describe Transactions::Statistics::Aggregate, type: :interactor do
  subject { described_class.for(**params) }

  let(:user) { create(:user, currency: "usd") }
  let(:account) { create(:account, user: user, currency: "usd") }
  let(:from) { Date.new(2026, 8, 1) }
  let(:to) { Date.new(2026, 8, 31) }
  let(:params) do
    {
      current_user: user,
      from: from,
      to: to,
      account_codes: nil,
      included_categories: nil,
      payment_method: nil
    }
  end

  context "with income and expense transactions spread across several days" do
    let!(:first_income) { create(:transaction, account: account, amount: 100, currency: "usd", occurred_at: Date.new(2026, 8, 1)) }
    let!(:second_income) { create(:transaction, account: account, amount: 50, currency: "usd", occurred_at: Date.new(2026, 8, 3)) }
    let!(:expense) { create(:transaction, account: account, amount: -30, currency: "usd", occurred_at: Date.new(2026, 8, 3)) }

    it "accumulates a running cumulative sum day by day across the interval" do
      rows = subject[:current][:daily_totals].first(4).map do |row|
        row.values_at(:date, :cumulative_income, :cumulative_expenses, :cumulative_net_balance)
      end

      expect(rows).to eq(
        [
          [ "2026-08-01", "100.00", "0.00", "100.00" ],
          [ "2026-08-02", "100.00", "0.00", "100.00" ],
          [ "2026-08-03", "150.00", "30.00", "120.00" ],
          [ "2026-08-04", "150.00", "30.00", "120.00" ]
        ],
      )
    end
  end

  context "with several categories in the same currency" do
    let!(:rent) { create(:transaction, account: account, amount: -50, currency: "usd", category: "rent", occurred_at: from) }
    let!(:groceries) { create(:transaction, account: account, amount: -200, currency: "usd", category: "groceries", occurred_at: from) }

    it "sorts category totals by amount descending" do
      expect(subject[:current][:expenses_by_category]).to eq(
        [
          { category: "groceries", amount: "200.00" },
          { category: "rent", amount: "50.00" }
        ],
      )
    end
  end

  context "when included_categories is given" do
    let!(:salary) { create(:transaction, account: account, amount: 300, currency: "usd", category: "salary", occurred_at: from) }
    let!(:rent) { create(:transaction, account: account, amount: -50, currency: "usd", category: "rent", occurred_at: from) }
    let!(:groceries) { create(:transaction, account: account, amount: -20, currency: "usd", category: "groceries", occurred_at: from) }

    context "with one category" do
      let(:params) { super().merge(included_categories: [ "rent" ]) }

      it "narrows the totals, the net balances and the category breakdowns alike" do
        expect(subject[:current]).to include(
          total_income: "0.00",
          total_expenses: "50.00",
          net_balance: "-50.00",
          income_by_category: [],
          expenses_by_category: [ { category: "rent", amount: "50.00" } ]
        )
      end

      it "narrows the forecast net balance along with the rest (the interval is fully elapsed, so it equals net_balance)" do
        expect(subject[:current][:forecast_net_balance]).to eq("-50.00")
      end
    end

    context "with several categories" do
      let(:params) { super().merge(included_categories: %w[salary groceries]) }

      it "keeps the union of those categories" do
        expect(subject[:current]).to include(total_income: "300.00", total_expenses: "20.00", net_balance: "280.00")
      end
    end

    context "with a category that matches nothing" do
      let(:params) { super().merge(included_categories: [ "nope" ]) }

      it "returns zero for every total" do
        expect(subject[:current]).to include(total_income: "0.00", total_expenses: "0.00", net_balance: "0.00")
      end
    end

    [ nil, [] ].each do |blank_value|
      context "with included_categories set to #{blank_value.inspect}" do
        let(:params) { super().merge(included_categories: blank_value) }

        it "applies no filter" do
          expect(subject[:current]).to include(total_income: "300.00", total_expenses: "70.00", net_balance: "230.00")
        end
      end
    end
  end

  context "when the filtered transactions span more than one account currency" do
    let(:eur_account) { create(:account, user: user, currency: "eur") }
    let!(:usd_to_eur_rate) { create(:currency_rate, left: "usd", right: "eur", rate: 0.5) }
    let!(:usd_rent) { create(:transaction, account: account, amount: -100, currency: "usd", category: "rent", occurred_at: from) }
    let!(:eur_rent) { create(:transaction, account: eur_account, amount: -100, currency: "eur", category: "rent", occurred_at: from) }

    it "converts each transaction into current_user's currency before summing the category total" do
      expect(subject[:current][:expenses_by_category]).to eq([ { category: "rent", amount: "300.00" } ])
    end

    it "converts each transaction before accumulating the daily cumulative totals" do
      expect(subject[:current][:daily_totals].first[:cumulative_expenses]).to eq("300.00")
    end
  end
end

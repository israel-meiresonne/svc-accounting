require "swagger_helper"

RSpec.describe "Statistics API", type: :request do
  path "/api/v1/statistics" do
    get "Returns aggregated transaction statistics for an interval and its predecessor" do
      tags "Statistics"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :from, in: :query, type: :string, required: true
      parameter name: :to, in: :query, type: :string, required: true
      parameter name: :account_codes, in: :query, type: :string, required: false
      parameter name: :category, in: :query, type: :string, required: false
      parameter name: :payment_method, in: :query, type: :string, required: false

      response "200", "compares a month-length interval against its predecessor" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-01" }
        let(:to) { "2026-08-31" }
        let!(:current_income) { create(:transaction, account: account, amount: 1000, currency: "usd", occurred_at: Date.new(2026, 8, 5)) }
        let!(:previous_income) { create(:transaction, account: account, amount: 400, currency: "usd", occurred_at: Date.new(2026, 7, 10)) }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["currency"]).to eq("usd")
          expect(body["current"]).to include("from" => "2026-08-01", "to" => "2026-08-31", "total_income" => "1000.00", "total_expenses" => "0.00")
          expect(body["previous"]).to include("from" => "2026-07-01", "to" => "2026-07-31", "total_income" => "400.00", "total_expenses" => "0.00")
          expect(body["previous"]).not_to have_key("forecast_net_balance")
        end
      end

      response "200", "compares a week-length interval against its predecessor" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-10" }
        let(:to) { "2026-08-16" }
        let!(:current_expense) { create(:transaction, account: account, amount: -140, currency: "usd", occurred_at: Date.new(2026, 8, 12)) }
        let!(:previous_expense) { create(:transaction, account: account, amount: -70, currency: "usd", occurred_at: Date.new(2026, 8, 5)) }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]).to include("from" => "2026-08-10", "to" => "2026-08-16", "total_expenses" => "140.00", "net_balance" => "-140.00")
          expect(body["previous"]).to include("from" => "2026-08-03", "to" => "2026-08-09", "total_expenses" => "70.00", "net_balance" => "-70.00")
        end
      end

      response "200", "filters by category" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-01" }
        let(:to) { "2026-08-31" }
        let(:category) { "rent" }
        let!(:rent) { create(:transaction, account: account, amount: -50, currency: "usd", category: "rent", occurred_at: Date.new(2026, 8, 5)) }
        let!(:groceries) { create(:transaction, account: account, amount: -20, currency: "usd", category: "groceries", occurred_at: Date.new(2026, 8, 5)) }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]["total_expenses"]).to eq("50.00")
          expect(body["current"]["expenses_by_category"]).to eq([ { "category" => "rent", "amount" => "50.00" } ])
        end
      end

      response "200", "filters by payment_method" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-01" }
        let(:to) { "2026-08-31" }
        let(:payment_method) { "cash" }
        let!(:cash_expense) { create(:transaction, account: account, amount: -30, currency: "usd", payment_method: "cash", occurred_at: Date.new(2026, 8, 5)) }
        let!(:card_expense) { create(:transaction, account: account, amount: -70, currency: "usd", payment_method: "credit_card", occurred_at: Date.new(2026, 8, 5)) }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]["total_expenses"]).to eq("30.00")
        end
      end

      response "200", "converts each transaction into current_user's currency before summing across accounts" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let!(:eur_account) { create(:account, user: user, currency: "eur") }
        let!(:usd_to_eur_rate) { create(:currency_rate, left: "usd", right: "eur", rate: 0.5) }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-01" }
        let(:to) { "2026-08-31" }
        let!(:usd_rent) { create(:transaction, account: account, amount: -100, currency: "usd", category: "rent", occurred_at: Date.new(2026, 8, 5)) }
        let!(:eur_rent) { create(:transaction, account: eur_account, amount: -100, currency: "eur", category: "rent", occurred_at: Date.new(2026, 8, 5)) }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]["total_expenses"]).to eq("300.00")
          expect(body["current"]["expenses_by_category"]).to eq([ { "category" => "rent", "amount" => "300.00" } ])
        end
      end

      response "200", "projects a linear forecast when the interval is half elapsed" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-01" }
        let(:to) { "2026-08-10" }
        let!(:income) { create(:transaction, account: account, amount: 100, currency: "usd", occurred_at: Date.new(2026, 8, 1)) }

        before { Timecop.freeze(Date.new(2026, 8, 5)) }
        after { Timecop.return }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]["net_balance"]).to eq("100.00")
          expect(body["current"]["forecast_net_balance"]).to eq("200.00")
        end
      end

      response "200", "returns the unprojected net balance when the interval has already fully elapsed" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-07-01" }
        let(:to) { "2026-07-10" }
        let!(:income) { create(:transaction, account: account, amount: 300, currency: "usd", occurred_at: Date.new(2026, 7, 2)) }

        before { Timecop.freeze(Date.new(2026, 8, 1)) }
        after { Timecop.return }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]["net_balance"]).to eq("300.00")
          expect(body["current"]["forecast_net_balance"]).to eq("300.00")
        end
      end

      response "200", "returns a null forecast when the interval hasn't started yet" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-09-01" }
        let(:to) { "2026-09-10" }

        before { Timecop.freeze(Date.new(2026, 8, 1)) }
        after { Timecop.return }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]).to have_key("forecast_net_balance")
          expect(body["current"]["forecast_net_balance"]).to be_nil
        end
      end

      response "200", "excludes an account_code that doesn't belong to current_user" do
        let!(:user) { create(:user, currency: "usd") }
        let!(:account) { create(:account, user: user, currency: "usd") }
        let!(:other_user) { create(:user, currency: "usd") }
        let!(:other_account) { create(:account, user: other_user, currency: "usd") }
        let!(:other_transaction) { create(:transaction, account: other_account, amount: 500, currency: "usd", occurred_at: Date.new(2026, 8, 5)) }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:from) { "2026-08-01" }
        let(:to) { "2026-08-31" }
        let(:account_codes) { other_account.code }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["current"]["total_income"]).to eq("0.00")
          expect(body["current"]["daily_totals"]).to all(include("cumulative_income" => "0.00"))
        end
      end
    end
  end
end

require "swagger_helper"

RSpec.describe "Transactions Create, Update and Stats API", type: :request do
  let!(:user) { create(:user, currency: "usd") }
  let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
  let!(:account) { create(:account, user: user, currency: "usd", initial_balance: 0) }
  let!(:counterparty) { create(:contact, first_name: "Jane", last_name: "Counterparty") }

  path "/api/v1/transactions" do
    post "Creates a transaction" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          account_code: { type: :string },
          amount: { type: :string },
          category: { type: :string },
          description: { type: :string },
          payment_method: { type: :string },
          occurred_at: { type: :string },
          counterparty_code: { type: :string },
          counterparty_options: { type: :object }
        },
        required: %w[account_code amount payment_method occurred_at]
      }

      response "201", "creates a transaction for an existing counterparty code" do
        let(:params) do
          {
            account_code: account.code,
            amount: "50.0",
            category: "groceries",
            description: "Weekly shop",
            payment_method: "cash",
            occurred_at: "2026-01-05T10:00:00Z",
            counterparty_code: counterparty.code
          }
        end

        run_test! do
          body = JSON.parse(response.body)

          expect(body["transaction"]).to include("amount" => "50.0", "currency" => "usd", "category" => "groceries")
          expect(body["transaction"]["counterparty"]).to eq("code" => counterparty.code, "display_name" => "Jane Counterparty")
        end
      end

      response "201", "creates a brand-new inline counterparty from counterparty_options" do
        let(:params) do
          {
            account_code: account.code,
            amount: "-20.0",
            payment_method: "bank_transfer",
            occurred_at: "2026-01-05T10:00:00Z",
            counterparty_options: { type: "company", company_name: "Acme Inc" }
          }
        end

        run_test! do
          body = JSON.parse(response.body)
          created = User.find_by(code: body["transaction"]["counterparty"]["code"])

          expect(created).to be_company_type
          expect(created.company_name).to eq("Acme Inc")
        end
      end

      response "201", "ignores a posted currency and stores the account's currency" do
        let!(:account) { create(:account, user: user, currency: "eur", initial_balance: 0) }
        let(:params) do
          {
            account_code: account.code,
            amount: "50.0",
            currency: "gbp",
            payment_method: "cash",
            occurred_at: "2026-01-05T10:00:00Z",
            counterparty_code: counterparty.code
          }
        end

        run_test! do
          expect(JSON.parse(response.body)["transaction"]["currency"]).to eq("eur")
          expect(account.transactions.last.currency).to eq("eur")
        end
      end

      response "404", "unknown account code" do
        let(:params) do
          {
            account_code: "acc_missing",
            amount: "50.0",
            payment_method: "cash",
            occurred_at: "2026-01-05T10:00:00Z",
            counterparty_code: counterparty.code
          }
        end

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          expect(JSON.parse(response.body)["code"]).to eq("not_found")
        end
      end

      response "404", "account code belonging to another user" do
        let!(:other_account) { create(:account, currency: "usd") }
        let(:params) do
          {
            account_code: other_account.code,
            amount: "50.0",
            payment_method: "cash",
            occurred_at: "2026-01-05T10:00:00Z",
            counterparty_code: counterparty.code
          }
        end

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          expect(JSON.parse(response.body)["code"]).to eq("not_found")
          expect(other_account.transactions.count).to eq(0)
        end
      end

      response "401", "no token" do
        let(:Authorization) { nil }
        let(:params) do
          {
            account_code: account.code,
            amount: "50.0",
            payment_method: "cash",
            occurred_at: "2026-01-05T10:00:00Z",
            counterparty_code: counterparty.code
          }
        end

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end
  end

  path "/api/v1/transactions/{code}" do
    parameter name: :code, in: :path, type: :string

    patch "Updates a transaction" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          account_code: { type: :string },
          amount: { type: :string },
          category: { type: :string },
          description: { type: :string },
          payment_method: { type: :string },
          occurred_at: { type: :string },
          counterparty_code: { type: :string },
          counterparty_options: { type: :object }
        },
        required: %w[account_code]
      }

      response "200", "updates the supplied fields" do
        let!(:transaction) do
          create(:transaction, account: account, counterparty: counterparty, amount: 50, category: "food", description: "old")
        end
        let(:code) { transaction.code }
        let(:params) { { account_code: account.code, category: "rent", description: "new" } }

        run_test! do
          expect(JSON.parse(response.body)["transaction"]).to include("category" => "rent", "description" => "new")
          expect(transaction.reload.counterparty).to eq(counterparty)
        end
      end

      response "200", "re-resolves the counterparty from a supplied code" do
        let!(:transaction) { create(:transaction, account: account, counterparty: counterparty) }
        let!(:new_counterparty) { create(:contact, first_name: "New", last_name: "Counterparty") }
        let(:code) { transaction.code }
        let(:params) { { account_code: account.code, counterparty_code: new_counterparty.code } }

        run_test! do
          expect(transaction.reload.counterparty).to eq(new_counterparty)
        end
      end

      response "200", "creates a brand-new inline counterparty from counterparty_options" do
        let!(:transaction) { create(:transaction, account: account, counterparty: counterparty) }
        let(:code) { transaction.code }
        let(:params) do
          { account_code: account.code, counterparty_options: { type: "company", company_name: "Acme Inc" } }
        end

        run_test! do
          expect(transaction.reload.counterparty).to have_attributes(type: "company", company_name: "Acme Inc")
        end
      end

      response "200", "ignores a posted currency" do
        let!(:transaction) { create(:transaction, account: account, counterparty: counterparty) }
        let(:code) { transaction.code }
        let(:params) { { account_code: account.code, currency: "gbp", category: "rent" } }

        run_test! do
          expect(transaction.reload.currency).to eq("usd")
        end
      end

      response "404", "transaction belonging to another user" do
        let!(:other_account) { create(:account, currency: "usd") }
        let!(:other_transaction) { create(:transaction, account: other_account, category: "food") }
        let(:code) { other_transaction.code }
        let(:params) { { account_code: other_account.code, category: "rent" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          expect(JSON.parse(response.body)["code"]).to eq("not_found")
          expect(other_transaction.reload.category).to eq("food")
        end
      end

      response "404", "unknown transaction code" do
        let(:code) { "txn_missing" }
        let(:params) { { account_code: account.code, category: "rent" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end
  end

  path "/api/v1/transactions/stats" do
    get "Returns income, expense and net totals for one account over a range" do
      tags "Transactions"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :account_code, in: :query, type: :string, required: true
      parameter name: :from, in: :query, type: :string, required: true
      parameter name: :to, in: :query, type: :string, required: true

      let(:account_code) { account.code }
      let(:from) { "2026-01-01T00:00:00Z" }
      let(:to) { "2026-01-31T23:59:59Z" }

      response "200", "splits income from expenses over the range" do
        let!(:income_transaction) { create(:transaction, account: account, amount: 300, occurred_at: "2026-01-10T12:00:00Z") }
        let!(:expense_transaction) { create(:transaction, account: account, amount: -120, occurred_at: "2026-01-15T12:00:00Z") }
        let!(:out_of_range_transaction) { create(:transaction, account: account, amount: 999, occurred_at: "2026-02-10T12:00:00Z") }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["total_income"]).to eq("amount" => "300.00", "currency" => "usd")
          expect(body["total_expenses"]).to eq("amount" => "120.00", "currency" => "usd")
          expect(body["net_balance"]).to eq("amount" => "180.00", "currency" => "usd")
        end
      end

      response "200", "excludes a soft-deleted transaction" do
        let!(:income_transaction) { create(:transaction, account: account, amount: 300, occurred_at: "2026-01-10T12:00:00Z") }
        let!(:deleted_transaction) do
          create(:transaction, account: account, amount: 500, occurred_at: "2026-01-20T12:00:00Z", deleted_at: Time.current)
        end

        run_test! do
          expect(JSON.parse(response.body)["total_income"]["amount"]).to eq("300.00")
        end
      end

      response "200", "includes a February 29 boundary in a leap year" do
        let(:from) { "2028-02-01T00:00:00Z" }
        let(:to) { "2028-02-29T23:59:59Z" }
        let!(:leap_day_income) { create(:transaction, account: account, amount: 300, occurred_at: "2028-02-29T12:00:00Z") }
        let!(:leap_day_expense) { create(:transaction, account: account, amount: -120, occurred_at: "2028-02-29T23:00:00Z") }
        let!(:next_day_transaction) { create(:transaction, account: account, amount: 999, occurred_at: "2028-03-01T00:00:01Z") }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["total_income"]["amount"]).to eq("300.00")
          expect(body["net_balance"]["amount"]).to eq("180.00")
        end
      end

      response "404", "account code belonging to another user" do
        let!(:other_account) { create(:account, currency: "usd") }
        let(:account_code) { other_account.code }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          expect(JSON.parse(response.body)["code"]).to eq("not_found")
        end
      end

      response "404", "unknown account code" do
        let(:account_code) { "acc_missing" }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end

      response "401", "no token" do
        let(:Authorization) { nil }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end
  end
end

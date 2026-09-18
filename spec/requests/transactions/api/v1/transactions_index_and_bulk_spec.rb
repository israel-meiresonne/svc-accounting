require "swagger_helper"

RSpec.describe "Transactions Index and Bulk Actions API", type: :request do
  def codes_in(response)
    JSON.parse(response.body)["data"].map { |transaction| transaction["code"] }
  end

  let(:user) { create(:user) }
  let(:token) { JsonWebTokens::Encode.for(user.code) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:other_user) { create(:user) }
  let(:other_account) { create(:account, user: other_user, currency: "usd") }
  let!(:other_user_transaction) { create(:transaction, account: other_account) }

  path "/api/v1/transactions" do
    get "Lists the current user's transactions" do
      tags "Transactions"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :from, in: :query, type: :string, required: false
      parameter name: :to, in: :query, type: :string, required: false
      parameter name: "filter[account_codes][]", in: :query, type: :array, items: { type: :string }, required: false
      parameter name: "filter[category]", in: :query, type: :string, required: false
      parameter name: "filter[payment_method]", in: :query, type: :string, required: false
      parameter name: :sort, in: :query, type: :string, required: false
      parameter name: :order, in: :query, type: :string, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response "200", "lists transactions filtered, sorted, and paginated" do
        let(:account) { create(:account, user: user, currency: "usd") }
        let(:second_account) { create(:account, user: user, currency: "usd") }
        let!(:food_cash) do
          create(:transaction, account: account, category: "food", payment_method: "cash", amount: 30, occurred_at: Time.zone.local(2026, 6, 1))
        end
        let!(:rent_transfer) do
          create(:transaction, account: second_account, category: "rent", payment_method: "bank_transfer", amount: 10, occurred_at: Time.zone.local(2026, 6, 10))
        end
        let!(:food_transfer) do
          create(:transaction, account: account, category: "food", payment_method: "bank_transfer", amount: 20, occurred_at: Time.zone.local(2026, 6, 15))
        end

        it "returns only the current user's own transactions" do
          get "/api/v1/transactions", headers: headers

          expect(response).to have_http_status(:ok)
          expect(codes_in(response)).to contain_exactly(food_cash.code, rent_transfer.code, food_transfer.code)
        end

        it "filters by account_codes" do
          get "/api/v1/transactions", params: { filter: { account_codes: [ account.code ] } }, headers: headers

          expect(codes_in(response)).to contain_exactly(food_cash.code, food_transfer.code)
        end

        it "filters by category" do
          get "/api/v1/transactions", params: { filter: { category: "food" } }, headers: headers

          expect(codes_in(response)).to contain_exactly(food_cash.code, food_transfer.code)
        end

        it "filters by payment_method" do
          get "/api/v1/transactions", params: { filter: { payment_method: "bank_transfer" } }, headers: headers

          expect(codes_in(response)).to contain_exactly(rent_transfer.code, food_transfer.code)
        end

        it "combines filters with cumulative AND semantics" do
          get "/api/v1/transactions", params: { filter: { category: "food", payment_method: "bank_transfer" } }, headers: headers

          expect(codes_in(response)).to contain_exactly(food_transfer.code)
        end

        it "filters by an occurred_at range" do
          get "/api/v1/transactions", params: { from: "2026-06-09", to: "2026-06-11" }, headers: headers

          expect(codes_in(response)).to contain_exactly(rent_transfer.code)
        end

        it "sorts by occurred_at ascending" do
          get "/api/v1/transactions", params: { sort: "occurred_at", order: "asc" }, headers: headers

          expect(codes_in(response)).to eq([ food_cash.code, rent_transfer.code, food_transfer.code ])
        end

        it "sorts by occurred_at descending when order is desc" do
          get "/api/v1/transactions", params: { sort: "occurred_at", order: "desc" }, headers: headers

          expect(codes_in(response)).to eq([ food_transfer.code, rent_transfer.code, food_cash.code ])
        end

        it "sorts by amount ascending" do
          get "/api/v1/transactions", params: { sort: "amount", order: "asc" }, headers: headers

          expect(codes_in(response)).to eq([ rent_transfer.code, food_transfer.code, food_cash.code ])
        end

        it "sorts by category ascending" do
          get "/api/v1/transactions", params: { sort: "category", order: "asc" }, headers: headers

          codes = codes_in(response)
          expect(codes.last).to eq(rent_transfer.code)
          expect(codes.first(2)).to contain_exactly(food_cash.code, food_transfer.code)
        end

        it "sorts by payment_method ascending" do
          get "/api/v1/transactions", params: { sort: "payment_method", order: "asc" }, headers: headers

          codes = codes_in(response)
          expect(codes.last).to eq(food_cash.code)
          expect(codes.first(2)).to contain_exactly(rent_transfer.code, food_transfer.code)
        end

        it "falls back to occurred_at descending for an unknown sort column" do
          get "/api/v1/transactions", params: { sort: "counterparty_id" }, headers: headers

          expect(codes_in(response)).to eq([ food_transfer.code, rent_transfer.code, food_cash.code ])
        end

        it "paginates the results" do
          get "/api/v1/transactions", params: { page: 1, per_page: 2 }, headers: headers
          body = JSON.parse(response.body)

          expect(body["data"].size).to eq(2)
          expect(body["meta"]).to eq("page" => 1, "per_page" => 2, "total_count" => 3, "total_pages" => 2)
        end

        it "returns the second page" do
          get "/api/v1/transactions", params: { page: 2, per_page: 2 }, headers: headers

          expect(codes_in(response).size).to eq(1)
        end

        it "caps per_page at 100" do
          get "/api/v1/transactions", params: { per_page: 500 }, headers: headers

          expect(JSON.parse(response.body)["meta"]["per_page"]).to eq(100)
        end

        it "never returns another user's transactions regardless of the filters supplied" do
          get "/api/v1/transactions", params: { filter: { account_codes: [ other_account.code ] } }, headers: headers

          expect(codes_in(response)).to be_empty
        end

        it "never exposes account_id or counterparty_id" do
          get "/api/v1/transactions", headers: headers
          transaction_json = JSON.parse(response.body)["data"].first

          expect(transaction_json).not_to have_key("account_id")
          expect(transaction_json).not_to have_key("counterparty_id")
        end
      end

      response "401", "missing token" do
        run_test!
      end
    end
  end

  path "/api/v1/transactions/bulk" do
    patch "Bulk-updates transaction properties" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          transaction_codes: { type: :array, items: { type: :string } },
          attributes: { type: :object }
        }
      }

      response "200", "updates the selected transactions' bulk-editable attributes" do
        let(:account) { create(:account, user: user) }
        let!(:transaction) { create(:transaction, account: account, category: "food") }
        let(:params) { { transaction_codes: [ transaction.code ], attributes: { category: "rent" } } }

        it "returns the number of updated transactions" do
          patch "/api/v1/transactions/bulk", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq("updated_count" => 1)
          expect(transaction.reload.category).to eq("rent")
        end
      end

      response "422", "a disallowed attribute is supplied" do
        let(:account) { create(:account, user: user) }
        let!(:transaction) { create(:transaction, account: account, amount: 10) }
        let(:params) { { transaction_codes: [ transaction.code ], attributes: { amount: 999 } } }

        it "rejects the request without updating anything" do
          patch "/api/v1/transactions/bulk", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["code"]).to eq("invalid_bulk_attributes")
          expect(transaction.reload.amount).to eq(10)
        end
      end
    end

    delete "Bulk soft-deletes transactions" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: { transaction_codes: { type: :array, items: { type: :string } } }
      }

      response "200", "soft-deletes the selected transactions" do
        let(:account) { create(:account, user: user) }
        let!(:transaction) { create(:transaction, account: account) }
        let(:params) { { transaction_codes: [ transaction.code ] } }

        it "returns the number of deleted transactions and removes them from the list endpoint" do
          delete "/api/v1/transactions/bulk", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq("deleted_count" => 1)

          get "/api/v1/transactions", headers: headers
          expect(codes_in(response)).not_to include(transaction.code)
        end
      end
    end
  end

  path "/api/v1/transactions/bulk/move" do
    post "Bulk-moves transactions to another account" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          transaction_codes: { type: :array, items: { type: :string } },
          destination_account_code: { type: :string }
        }
      }

      response "200", "moves the selected transactions to the destination account" do
        let(:source_account) { create(:account, user: user, currency: "usd") }
        let(:destination_account) { create(:account, user: user, currency: "usd") }
        let!(:transaction) { create(:transaction, account: source_account, currency: "usd") }
        let(:params) { { transaction_codes: [ transaction.code ], destination_account_code: destination_account.code } }

        it "returns the number of moved transactions" do
          post "/api/v1/transactions/bulk/move", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq("moved_count" => 1)
          expect(transaction.reload.account).to eq(destination_account)
        end
      end

      response "422", "the destination account's currency does not match every selected transaction" do
        let(:source_account) { create(:account, user: user, currency: "usd") }
        let(:destination_account) { create(:account, user: user, currency: "eur") }
        let!(:transaction) { create(:transaction, account: source_account, currency: "usd") }
        let(:params) { { transaction_codes: [ transaction.code ], destination_account_code: destination_account.code } }

        it "moves nothing" do
          post "/api/v1/transactions/bulk/move", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["code"]).to eq("currency_mismatch")
          expect(transaction.reload.account).to eq(source_account)
        end
      end

      response "404", "the destination account does not belong to the current user" do
        let(:source_account) { create(:account, user: user, currency: "usd") }
        let!(:transaction) { create(:transaction, account: source_account, currency: "usd") }
        let(:params) { { transaction_codes: [ transaction.code ], destination_account_code: other_account.code } }

        it "returns not found" do
          post "/api/v1/transactions/bulk/move", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  path "/api/v1/transactions/bulk/export_csv" do
    post "Exports selected transactions as a CSV file" do
      tags "Transactions"
      consumes "application/json"
      produces "text/csv"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: { transaction_codes: { type: :array, items: { type: :string } } }
      }

      response "200", "returns a CSV attachment of the selected transactions" do
        let(:account) { create(:account, user: user, name: "Checking") }
        let(:counterparty) { create(:contact, first_name: "John", last_name: "Doe") }
        let!(:transaction) do
          create(:transaction, account: account, counterparty: counterparty, amount: 42, category: "food", payment_method: "cash", occurred_at: Time.zone.local(2026, 6, 15))
        end
        let(:params) { { transaction_codes: [ transaction.code ] } }

        it "returns a csv attachment with the expected columns" do
          post "/api/v1/transactions/bulk/export_csv", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include("text/csv")
          expect(response.headers["Content-Disposition"]).to include("attachment", "transactions.csv")
          expect(response.body.lines.map(&:strip)).to eq(
            [
              "date,amount,currency,category,payment_method,counterparty,description,account",
              "2026-06-15,42.0,usd,food,cash,John Doe,\"\",Checking"
            ],
          )
        end
      end
    end
  end

  path "/api/v1/transactions/bulk/generate_report" do
    post "Generates a PDF report for the selected transactions" do
      tags "Transactions"
      consumes "application/json"
      produces "application/pdf"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          transaction_codes: { type: :array, items: { type: :string } },
          title: { type: :string },
          description: { type: :string },
          reporting_currency: { type: :string }
        }
      }

      response "200", "returns a PDF attachment" do
        let(:account) { create(:account, user: user, currency: "usd") }
        let!(:transaction) { create(:transaction, account: account, currency: "usd") }
        let(:params) { { transaction_codes: [ transaction.code ], title: "Q2 report", description: "Quarterly summary", reporting_currency: "usd" } }

        it "returns a non-empty pdf attachment" do
          post "/api/v1/transactions/bulk/generate_report", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include("application/pdf")
          expect(response.headers["Content-Disposition"]).to include("attachment", "report.pdf")
          expect(response.body).to start_with("%PDF-")
        end
      end

      response "422", "the selection is empty" do
        let(:params) { { transaction_codes: [], title: "Q2 report", description: "Quarterly summary", reporting_currency: "usd" } }

        it "rejects the request before building any document" do
          post "/api/v1/transactions/bulk/generate_report", params: params, headers: headers, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["code"]).to eq("empty_selection")
        end
      end
    end
  end
end

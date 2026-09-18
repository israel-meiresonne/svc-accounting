require "swagger_helper"

RSpec.describe "Accounts API", type: :request do
  let!(:user) { create(:user, currency: "usd") }
  let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }

  path "/api/v1/accounts" do
    get "Lists the current user's accounts" do
      tags "Accounts"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false

      response "200", "accounts with a converted summary" do
        let!(:account) { create(:account, user: user, currency: "usd", initial_balance: 100) }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["accounts"].first).to include("code" => account.code, "currency" => "usd")
          expect(body["summary"]).to eq("amount" => "100.00", "currency" => "usd")
        end
      end

      response "200", "a zero-amount summary rather than none when there are no accounts" do
        run_test! do
          body = JSON.parse(response.body)

          expect(body["accounts"]).to eq([])
          expect(body["summary"]).to eq("amount" => "0.00", "currency" => "usd")
        end
      end
    end

    post "Creates an account" do
      tags "Accounts"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          currency: { type: :string },
          initial_balance: { type: :number, nullable: true },
          current_balance: { type: :number, nullable: true }
        },
        required: %w[name currency]
      }

      response "201", "account created in direct-balance mode" do
        let(:params) { { name: "Checking", currency: "usd", initial_balance: 100 } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["account"]).to include("name" => "Checking", "currency" => "usd")
          expect(body["account"]["balance"]).to eq("amount" => "100.00", "currency" => "usd")
        end
      end

      response "201", "account created in current-balance mode has an immediately correct balance" do
        let(:params) { { name: "Checking", currency: "usd", current_balance: 250 } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["account"]["balance"]).to eq("amount" => "250.00", "currency" => "usd")
        end
      end

      response "422", "neither balance field is given" do
        let(:params) { { name: "Checking", currency: "usd" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["code"]).to eq("missing_balance")
        end
      end
    end
  end

  path "/api/v1/accounts/{code}" do
    parameter name: :code, in: :path, type: :string

    patch "Updates an account" do
      tags "Accounts"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          currency: { type: :string }
        }
      }

      response "200", "account updated, returning the actual record" do
        let!(:account) { create(:account, user: user, name: "Checking", currency: "usd") }
        let(:code) { account.code }
        let(:params) { { name: "Savings" } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["account"]).to include("code" => account.code, "name" => "Savings")
        end
      end

      response "422", "currency change rejected once the account has an active transaction" do
        let!(:account) { create(:account, user: user, currency: "usd") }
        let!(:transaction) { create(:transaction, account: account, currency: "usd") }
        let(:code) { account.code }
        let(:params) { { currency: "eur" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["code"]).to eq("currency_change_not_allowed")
        end
      end

      response "404", "a code belonging to a different user" do
        let!(:other_user) { create(:user) }
        let!(:account) { create(:account, user: other_user) }
        let(:code) { account.code }
        let(:params) { { name: "Savings" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end

    delete "Deletes an account" do
      tags "Accounts"
      parameter name: :Authorization, in: :header, type: :string, required: false

      response "204", "account soft-deleted" do
        let!(:account) { create(:account, user: user) }
        let(:code) { account.code }

        run_test! do
          expect(account.reload.deleted_at).not_to be_nil
        end
      end

      response "404", "a code belonging to a different user" do
        let!(:other_user) { create(:user) }
        let!(:account) { create(:account, user: other_user) }
        let(:code) { account.code }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end
  end
end

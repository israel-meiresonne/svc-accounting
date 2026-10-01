require "swagger_helper"

RSpec.describe "Transactions Categories API", type: :request do
  let!(:user) { create(:user) }
  let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
  let!(:account) { create(:account, user: user) }

  path "/api/v1/transactions/categories" do
    get "Lists every distinct category the current user has used" do
      tags "Transactions"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false

      response "200", "returns the user's own categories, sorted, without another user's" do
        let!(:rent) { create(:transaction, account: account, category: "Rent") }
        let!(:groceries) { create(:transaction, account: account, category: "Groceries") }
        let!(:other_user_transaction) { create(:transaction, account: create(:account), category: "Holidays") }

        run_test! do
          expect(JSON.parse(response.body)).to eq("categories" => %w[Groceries Rent])
        end
      end

      response "200", "returns an empty list when nothing is categorized" do
        run_test! do
          expect(JSON.parse(response.body)).to eq("categories" => [])
        end
      end

      response "401", "no token" do
        let(:Authorization) { nil }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end
  end
end

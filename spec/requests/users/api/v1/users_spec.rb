require "swagger_helper"

RSpec.describe "Users API", type: :request do
  path "/api/v1/users/create" do
    post "Creates a user" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string },
          last_name: { type: :string },
          email: { type: :string },
          password: { type: :string },
          password_confirmation: { type: :string },
          currency: { type: :string }
        },
        required: %w[first_name last_name email password password_confirmation currency]
      }

      response "201", "user created" do
        let(:params) do
          {
            first_name: "Jane",
            last_name: "Doe",
            email: "jane@example.com",
            password: "password123",
            password_confirmation: "password123",
            currency: "usd"
          }
        end

        run_test! do
          body = JSON.parse(response.body)

          expect(body).to include("token", "user")
          expect(body["user"]).to include("email" => "jane@example.com")
        end
      end

      response "422", "duplicate email" do
        let!(:existing_user) { create(:user, email: "jane@example.com") }
        let(:params) do
          {
            first_name: "Jane",
            last_name: "Doe",
            email: "jane@example.com",
            password: "password123",
            password_confirmation: "password123",
            currency: "usd"
          }
        end

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end

      response "422", "password confirmation mismatch" do
        let(:params) do
          {
            first_name: "Jane",
            last_name: "Doe",
            email: "jane@example.com",
            password: "password123",
            password_confirmation: "somethingelse",
            currency: "usd"
          }
        end

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end
  end

  path "/api/v1/users/login" do
    post "Logs a user in" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response "200", "logged in" do
        let!(:user) { create(:user, email: "jane@example.com", password: "password123", password_confirmation: "password123") }
        let(:params) { { email: "jane@example.com", password: "password123" } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body).to include("token", "user")
          expect(body["user"]).to include("email" => "jane@example.com")
        end
      end

      response "401", "wrong password" do
        let!(:user) { create(:user, email: "jane@example.com", password: "password123", password_confirmation: "password123") }
        let(:params) { { email: "jane@example.com", password: "wrongpassword" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end

      response "401", "unknown email" do
        let(:params) { { email: "unknown@example.com", password: "password123" } }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["code"]).to eq("invalid_credentials")
          expect(body["message"]).to eq("Email or password is incorrect")
        end
      end
    end
  end

  path "/api/v1/users/me" do
    get "Returns the current user" do
      tags "Users"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false

      response "200", "current user" do
        let!(:user) { create(:user, email: "jane@example.com") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["user"]).to include("email" => "jane@example.com")
        end
      end

      response "401", "no token" do
        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end

      response "401", "expired token" do
        let!(:user) { create(:user, email: "jane@example.com") }
        let!(:token) { JsonWebTokens::Encode.for(user.code) }
        let(:Authorization) { "Bearer #{token}" }

        before { Timecop.travel(8.days.from_now) }
        after { Timecop.return }

        schema type: :object, properties: { code: { type: :string }, message: { type: :string }, details: { type: :object } }

        run_test!
      end
    end

    patch "Updates the current user's currency" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: { currency: { type: :string } },
        required: %w[currency]
      }

      response "200", "currency updated" do
        let!(:user) { create(:user, email: "jane@example.com", currency: "usd") }
        let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
        let(:params) { { currency: "eur" } }

        run_test! do
          body = JSON.parse(response.body)

          expect(body["user"]).to include("currency" => "eur")
          expect(user.reload.currency).to eq("eur")
        end
      end
    end
  end

  path "/api/v1/users/counterparties" do
    get "Searches the counterparties available to the current user" do
      tags "Users"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :q, in: :query, type: :string, required: false

      let!(:user) { create(:user, email: "jane@example.com") }
      let!(:account) { create(:account, user: user, currency: "usd") }
      let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
      let(:q) { "searchable" }

      response "200", "returns contact and company counterparties matching the query" do
        let!(:contact) { create(:contact, first_name: "Searchable", last_name: "Contact") }
        let!(:company) { create(:company, company_name: "Searchable Company") }
        let!(:unrelated_contact) { create(:contact, first_name: "Other", last_name: "Person") }

        run_test! do
          results = JSON.parse(response.body)["counterparties"]

          expect(results.map { |result| result["code"] }).to contain_exactly(contact.code, company.code)
          expect(results.map { |result| result["display_name"] }).to contain_exactly("Searchable Contact", "Searchable Company")
          expect(results.map { |result| result["image"] }).to all(be_nil)
        end
      end

      response "200", "includes a user who is already a counterparty on the current user's transaction" do
        let!(:known_user) { create(:user, first_name: "Searchable", last_name: "Known") }
        let!(:transaction) { create(:transaction, account: account, counterparty: known_user) }

        run_test! do
          results = JSON.parse(response.body)["counterparties"]

          expect(results.map { |result| result["code"] }).to include(known_user.code)
        end
      end

      response "200", "excludes a user who has never transacted with the current user" do
        let!(:stranger) { create(:user, first_name: "Searchable", last_name: "Stranger") }

        run_test! do
          results = JSON.parse(response.body)["counterparties"]

          expect(results.map { |result| result["code"] }).not_to include(stranger.code)
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

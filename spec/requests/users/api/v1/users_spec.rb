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
  end
end

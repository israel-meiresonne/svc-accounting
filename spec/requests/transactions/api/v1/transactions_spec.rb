require "swagger_helper"

RSpec.describe "Transactions CSV Import API", type: :request do
  let!(:user) { create(:user, currency: "usd") }
  let(:Authorization) { "Bearer #{JsonWebTokens::Encode.for(user.code)}" }
  let!(:account) { create(:account, user: user, currency: "usd", initial_balance: 0) }

  path "/api/v1/transactions/import/preview" do
    post "Previews a CSV transaction import" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: { rows: { type: :array, items: { type: :object } } },
        required: %w[rows]
      }

      response "200", "a valid row resolves a new contact counterparty" do
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: 50,
                currency: "usd",
                payment_method: "cash",
                category: "groceries",
                description: "Weekly shop",
                counterparty_type: "contact",
                counterparty_first_name: "New",
                counterparty_last_name: "Contact",
                counterparty_email: nil
              }
            ]
          }
        end

        run_test! do
          body = JSON.parse(response.body)
          row = body["rows"].first

          expect(row["status"]).to eq("ok")
          expect(User.find_by(code: row["counterparty_code"])).to be_contact_type
        end
      end

      response "200", "a valid row resolves to an existing user by email instead of creating a duplicate" do
        let!(:existing_counterparty) { create(:contact, email: "landlord@example.com") }
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: -50,
                currency: "usd",
                payment_method: "bank_transfer",
                counterparty_type: "contact",
                counterparty_first_name: "Landlord",
                counterparty_last_name: "Name",
                counterparty_email: "landlord@example.com"
              }
            ]
          }
        end

        run_test! do
          body = JSON.parse(response.body)
          row = body["rows"].first

          expect(row["counterparty_code"]).to eq(existing_counterparty.code)
          expect(User.where(email: "landlord@example.com").count).to eq(1)
        end
      end

      response "200", "a currency-mismatched row is marked invalid" do
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: 50,
                currency: "eur",
                payment_method: "cash",
                counterparty_type: "contact",
                counterparty_first_name: "New",
                counterparty_last_name: "Contact"
              }
            ]
          }
        end

        run_test! do
          body = JSON.parse(response.body)
          row = body["rows"].first

          expect(row["status"]).to eq("invalid")
          expect(row["errors"]).to be_present
        end
      end

      response "200", "a row matching an existing active transaction is marked duplicate" do
        let!(:existing_counterparty) { create(:contact, email: "landlord@example.com") }
        let!(:existing_transaction) do
          create(:transaction, account: account, amount: -50, currency: "usd", counterparty: existing_counterparty,
                                occurred_at: "2026-01-05T00:00:00Z")
        end
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: -50,
                currency: "usd",
                payment_method: "cash",
                counterparty_type: "contact",
                counterparty_first_name: "Landlord",
                counterparty_last_name: "Name",
                counterparty_email: "landlord@example.com"
              }
            ]
          }
        end

        run_test! do
          body = JSON.parse(response.body)
          row = body["rows"].first

          expect(row["status"]).to eq("duplicate")
          expect(row["duplicate_group_id"]).to eq(row["dedup_hash"])
        end
      end
    end
  end

  path "/api/v1/transactions/import/commit" do
    post "Commits a previewed CSV transaction import" do
      tags "Transactions"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, type: :string, required: false
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: { rows: { type: :array, items: { type: :object } } },
        required: %w[rows]
      }

      response "200", "a row with no resolution is inserted as a new transaction" do
        let!(:counterparty) { create(:contact, email: "new@example.com") }
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: 50,
                currency: "usd",
                payment_method: "cash",
                counterparty_code: counterparty.code
              }
            ]
          }
        end

        run_test! do
          expect(Transaction.active.where(account: account).count).to eq(1)
          expect(JSON.parse(response.body)).to eq("imported_count" => 1)
        end
      end

      response "200", "a duplicate row resolved as add_anyway inserts a second transaction" do
        let!(:counterparty) { create(:contact, email: "landlord@example.com") }
        let!(:existing_transaction) do
          create(:transaction, account: account, amount: -50, currency: "usd", counterparty: counterparty,
                                occurred_at: "2026-01-05T00:00:00Z")
        end
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: -50,
                currency: "usd",
                payment_method: "cash",
                counterparty_code: counterparty.code,
                dedup_hash: existing_transaction.dedup_hash,
                resolution: "add_anyway"
              }
            ]
          }
        end

        run_test! do
          expect(Transaction.active.where(account: account, dedup_hash: existing_transaction.dedup_hash).count).to eq(2)
        end
      end

      response "200", "a duplicate row resolved as overwrite updates the existing transaction" do
        let!(:counterparty) { create(:contact, email: "landlord@example.com") }
        let!(:existing_transaction) do
          create(:transaction, account: account, amount: -50, currency: "usd", counterparty: counterparty,
                                occurred_at: "2026-01-05T00:00:00Z", description: "Old")
        end
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: -50,
                currency: "usd",
                payment_method: "cash",
                description: "Updated",
                counterparty_code: counterparty.code,
                dedup_hash: existing_transaction.dedup_hash,
                resolution: "overwrite"
              }
            ]
          }
        end

        run_test! do
          expect(Transaction.active.where(account: account).count).to eq(1)
          expect(existing_transaction.reload.description).to eq("Updated")
        end
      end

      response "200", "a duplicate row resolved as drop is not persisted" do
        let!(:counterparty) { create(:contact, email: "landlord@example.com") }
        let!(:existing_transaction) do
          create(:transaction, account: account, amount: -50, currency: "usd", counterparty: counterparty,
                                occurred_at: "2026-01-05T00:00:00Z")
        end
        let(:params) do
          {
            rows: [
              {
                account_code: account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: -50,
                currency: "usd",
                payment_method: "cash",
                counterparty_code: counterparty.code,
                dedup_hash: existing_transaction.dedup_hash,
                resolution: "drop"
              }
            ]
          }
        end

        run_test! do
          expect(Transaction.active.where(account: account).count).to eq(1)
          expect(JSON.parse(response.body)).to eq("imported_count" => 0)
        end
      end

      response "200", "back-derives initial_balance for a first import into a current-balance-mode account" do
        let!(:current_balance_account) do
          create(:account, user: user, currency: "usd", initial_balance: 500, balance_at_creation: 500)
        end
        let!(:counterparty) { create(:contact, email: "new@example.com") }
        let(:params) do
          {
            rows: [
              {
                account_code: current_balance_account.code,
                occurred_at: "2026-01-05T00:00:00Z",
                amount: 200,
                currency: "usd",
                payment_method: "cash",
                counterparty_code: counterparty.code
              },
              {
                account_code: current_balance_account.code,
                occurred_at: "2026-01-06T00:00:00Z",
                amount: -50,
                currency: "usd",
                payment_method: "cash",
                counterparty_code: counterparty.code
              }
            ]
          }
        end

        run_test! do
          expect(current_balance_account.reload.initial_balance).to eq(350)
          expect(current_balance_account.reload.balance_at_creation).to be_nil
        end
      end
    end
  end
end

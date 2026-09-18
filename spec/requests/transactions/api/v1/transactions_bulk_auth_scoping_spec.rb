require "rails_helper"

RSpec.describe "Transactions bulk endpoints auth scoping", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebTokens::Encode.for(user.code) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:own_account) { create(:account, user: user, currency: "usd") }
  let(:other_user) { create(:user) }
  let(:other_account) { create(:account, user: other_user, currency: "usd") }
  let!(:other_transaction) { create(:transaction, account: other_account, category: "food", currency: "usd") }

  it "affects zero rows on bulk_update when every supplied code belongs to another user, without a 403 or 404" do
    patch "/api/v1/transactions/bulk", params: { transaction_codes: [ other_transaction.code ], attributes: { category: "rent" } }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq("updated_count" => 0)
    expect(other_transaction.reload.category).to eq("food")
  end

  it "affects zero rows on bulk_delete when every supplied code belongs to another user, without a 403 or 404" do
    delete "/api/v1/transactions/bulk", params: { transaction_codes: [ other_transaction.code ] }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq("deleted_count" => 0)
    expect(other_transaction.reload.deleted_at).to be_nil
  end

  it "affects zero rows on bulk_move when every supplied code belongs to another user, without a 403 or 404" do
    post "/api/v1/transactions/bulk/move", params: { transaction_codes: [ other_transaction.code ], destination_account_code: own_account.code }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq("moved_count" => 0)
    expect(other_transaction.reload.account).to eq(other_account)
  end

  it "produces a header-only CSV on bulk_export_csv when every supplied code belongs to another user, without a 403 or 404" do
    post "/api/v1/transactions/bulk/export_csv", params: { transaction_codes: [ other_transaction.code ] }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.body.lines.map(&:strip)).to eq([ "date,amount,currency,category,payment_method,counterparty,description,account" ])
  end

  context "bulk_generate_report" do
    let(:base_params) { { title: "t", description: "d", reporting_currency: "usd" } }

    it "responds with the empty_selection error, never a 403 or 404, when the code belongs to another user" do
      post "/api/v1/transactions/bulk/generate_report", params: base_params.merge(transaction_codes: [ other_transaction.code ]), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["code"]).to eq("empty_selection")
    end

    it "responds with the empty_selection error, never a 403 or 404, when the code is unknown/nonexistent" do
      post "/api/v1/transactions/bulk/generate_report", params: base_params.merge(transaction_codes: [ "txn_does_not_exist" ]), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["code"]).to eq("empty_selection")
    end

    it "responds with the empty_selection error, never a 403 or 404, when transaction_codes is absent" do
      post "/api/v1/transactions/bulk/generate_report", params: base_params, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["code"]).to eq("empty_selection")
    end
  end
end

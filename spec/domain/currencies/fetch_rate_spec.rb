require "rails_helper"

RSpec.describe Currencies::FetchRate, type: :interactor do
  subject { described_class.for(currency) }

  let(:currency) { "eur" }

  around do |example|
    original_currencylayer_key = ENV["CURRENCYLAYER_API_KEY"]
    original_freecurrencyapi_key = ENV["FREECURRENCYAPI_API_KEY"]
    ENV["CURRENCYLAYER_API_KEY"] = "currencylayer_test_key"
    ENV["FREECURRENCYAPI_API_KEY"] = "freecurrencyapi_test_key"

    example.run

    ENV["CURRENCYLAYER_API_KEY"] = original_currencylayer_key
    ENV["FREECURRENCYAPI_API_KEY"] = original_freecurrencyapi_key
  end

  def stub_currencylayer(status:, body:)
    stub_request(:get, "http://apilayer.net/api/live")
      .with(query: { access_key: "currencylayer_test_key", source: "USD", currencies: "EUR" })
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_freecurrencyapi(status:, body:)
    stub_request(:get, "https://api.freecurrencyapi.com/v1/latest")
      .with(query: { apikey: "freecurrencyapi_test_key", base_currency: "USD", currencies: "EUR" })
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  context "when the primary provider succeeds" do
    before { stub_currencylayer(status: 200, body: { quotes: { USDEUR: 0.8 } }) }

    it "stores the rate without calling the fallback provider" do
      expect { subject }.to change { CurrencyRate.find_by(left: "usd", right: "eur")&.rate }.to(BigDecimal("0.8"))
    end

    it "never requests the fallback provider" do
      subject

      expect(a_request(:get, "https://api.freecurrencyapi.com/v1/latest")).not_to have_been_made
    end
  end

  context "when the primary provider fails and the fallback provider succeeds" do
    before do
      stub_currencylayer(status: 500, body: {})
      stub_freecurrencyapi(status: 200, body: { data: { EUR: 0.75 } })
    end

    it "still stores the rate from the fallback provider" do
      expect { subject }.to change { CurrencyRate.find_by(left: "usd", right: "eur")&.rate }.to(BigDecimal("0.75"))
    end
  end

  context "when every provider fails" do
    before do
      stub_currencylayer(status: 500, body: {})
      stub_freecurrencyapi(status: 500, body: {})
    end

    context "when a rate already exists for the currency" do
      let!(:existing_rate) { create(:currency_rate, left: "usd", right: "eur", rate: 0.9) }

      it "leaves the existing rate untouched" do
        expect { subject }.not_to change { existing_rate.reload.rate }
      end

      it "does not raise" do
        expect { subject }.not_to raise_error
      end
    end

    context "when no rate exists yet for the currency" do
      it "does not raise and does not create a rate" do
        expect { subject }.not_to raise_error
        expect(CurrencyRate.find_by(left: "usd", right: "eur")).to be_nil
      end
    end
  end
end

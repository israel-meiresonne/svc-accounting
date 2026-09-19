require "rails_helper"

RSpec.describe Currencies::Convert, type: :interactor do
  subject { described_class.for(money, to) }

  let(:money) { Currencies::Money.new(amount: 100, currency: "usd") }
  let(:to) { "usd" }

  context "when converting to the same currency" do
    it "returns the same money object without looking up a rate" do
      expect(subject).to equal(money)
    end
  end

  context "when converting from usd to another currency" do
    let(:to) { "eur" }
    let!(:usd_to_eur) { create(:currency_rate, left: "usd", right: "eur", rate: 0.8) }

    it "performs a single lookup, from usd to the target currency" do
      expect(subject.as_json).to eq(amount: "80.00", currency: "eur")
    end
  end

  context "when converting to usd from another currency" do
    let(:money) { Currencies::Money.new(amount: 80, currency: "eur") }
    let(:to) { "usd" }
    let!(:usd_to_eur) { create(:currency_rate, left: "usd", right: "eur", rate: 0.8) }

    it "performs a single lookup, from the source currency to usd" do
      expect(subject.as_json).to eq(amount: "100.00", currency: "usd")
    end
  end

  context "when converting between two non-central currencies" do
    let(:money) { Currencies::Money.new(amount: 80, currency: "eur") }
    let(:to) { "gbp" }
    let!(:usd_to_eur) { create(:currency_rate, left: "usd", right: "eur", rate: 0.8) }
    let!(:usd_to_gbp) { create(:currency_rate, left: "usd", right: "gbp", rate: 0.75) }

    it "routes through the central currency with two lookups" do
      expect(subject.as_json).to eq(amount: "75.00", currency: "gbp")
    end
  end

  context "when no rate exists for the needed currency" do
    let(:to) { "eur" }

    around do |example|
      original_currencylayer_key = ENV["CURRENCYLAYER_API_KEY"]
      original_freecurrencyapi_key = ENV["FREECURRENCYAPI_API_KEY"]
      ENV["CURRENCYLAYER_API_KEY"] = "currencylayer_test_key"
      ENV["FREECURRENCYAPI_API_KEY"] = "freecurrencyapi_test_key"

      example.run

      ENV["CURRENCYLAYER_API_KEY"] = original_currencylayer_key
      ENV["FREECURRENCYAPI_API_KEY"] = original_freecurrencyapi_key
    end

    context "and a provider can supply one live" do
      before do
        stub_request(:get, "http://apilayer.net/api/live")
          .with(query: { access_key: "currencylayer_test_key", source: "USD", currencies: "EUR" })
          .to_return(
            status: 200,
            body: { quotes: { USDEUR: 0.8 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "fetches and stores the rate on demand instead of raising" do
        expect(subject.as_json).to eq(amount: "80.00", currency: "eur")
      end
    end

    context "and every provider fails to supply one" do
      before do
        stub_request(:get, "http://apilayer.net/api/live")
          .with(query: { access_key: "currencylayer_test_key", source: "USD", currencies: "EUR" })
          .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })
        stub_request(:get, "https://api.freecurrencyapi.com/v1/latest")
          .with(query: { apikey: "freecurrencyapi_test_key", base_currency: "USD", currencies: "EUR" })
          .to_return(status: 500, body: "{}", headers: { "Content-Type" => "application/json" })
      end

      it "still raises Currencies::Errors::RateUnavailableError after attempting a live fetch" do
        expect { subject }.to raise_error(Currencies::Errors::RateUnavailableError)
      end
    end
  end
end

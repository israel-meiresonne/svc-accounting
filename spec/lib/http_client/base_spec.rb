require "rails_helper"

RSpec.describe HttpClient::Base, type: :interactor do
  subject { described_class.for(options) }

  let(:options) { { base_url: "https://example.com", method: :get, path: "/ping" } }

  context "when a required option is missing" do
    let(:options) { { method: :get, path: "/ping" } }

    it "raises HttpClient::Errors::InvalidParametersError" do
      expect { subject }.to raise_error(HttpClient::Errors::InvalidParametersError)
    end
  end

  context "when the upstream responds with a non-2xx status" do
    before do
      stub_request(:get, "https://example.com/ping").to_return(status: 500, body: "Internal Server Error")
    end

    it "raises HttpClient::Errors::RequestError with the response status and body in details" do
      expect { subject }.to raise_error(HttpClient::Errors::RequestError) do |error|
        expect(error.details).to eq(status: 500, body: "Internal Server Error")
      end
    end
  end
end

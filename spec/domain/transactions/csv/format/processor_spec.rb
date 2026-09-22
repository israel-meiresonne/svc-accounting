require "rails_helper"

RSpec.describe Transactions::Csv::Format::Processor, type: :interactor do
  subject { described_class.for(provider: provider, user: user, csv_rows: csv_rows) }

  let!(:user) { create(:user) }
  let(:csv_rows) { instance_double(CSV::Table) }

  context "with a known provider" do
    let(:provider) { "revolut" }

    it "dispatches to that provider's formatter" do
      expect(Transactions::Csv::Format::FromRevolut).to receive(:for).with(user: user, csv_rows: csv_rows)

      subject
    end
  end

  context "with an unknown provider" do
    let(:provider) { "unknown_bank" }

    it "raises UnknownCsvProviderError with the provider name in details" do
      expect { subject }.to raise_error(Transactions::Errors::UnknownCsvProviderError) do |error|
        expect(error.details).to eq(provider: "unknown_bank")
      end
    end
  end
end

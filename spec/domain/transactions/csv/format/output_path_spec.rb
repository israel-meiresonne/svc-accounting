require "rails_helper"

RSpec.describe Transactions::Csv::Format::OutputPath, type: :interactor do
  subject { described_class.for("revolut") }

  before { FileUtils.rm_rf(described_class::DIRECTORY) }

  after { FileUtils.rm_rf(described_class::DIRECTORY) }

  context "when the directory is empty" do
    it "returns the first sequential file path" do
      expect(subject.to_s).to end_with("01-formatted-from-revolut.csv")
    end
  end

  context "when the directory already has a file" do
    let!(:existing_file) do
      FileUtils.mkdir_p(described_class::DIRECTORY)
      FileUtils.touch(described_class::DIRECTORY.join("01-formatted-from-other.csv"))
    end

    it "returns the next sequential file path regardless of the existing file's provider" do
      expect(subject.to_s).to end_with("02-formatted-from-revolut.csv")
    end
  end
end

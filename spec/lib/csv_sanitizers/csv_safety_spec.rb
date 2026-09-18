require "rails_helper"

RSpec.describe CsvSanitizers::CsvSafety do
  describe ".sanitize_cell" do
    context "when the cell starts with =" do
      it "prefixes the cell with a single quote" do
        expect(described_class.sanitize_cell("=SUM(A1:A2)")).to eq("'=SUM(A1:A2)")
      end
    end

    context "when the cell starts with +" do
      it "prefixes the cell with a single quote" do
        expect(described_class.sanitize_cell("+1234")).to eq("'+1234")
      end
    end

    context "when the cell starts with -" do
      it "prefixes the cell with a single quote" do
        expect(described_class.sanitize_cell("-1234")).to eq("'-1234")
      end
    end

    context "when the cell starts with @" do
      it "prefixes the cell with a single quote" do
        expect(described_class.sanitize_cell("@SUM(A1:A2)")).to eq("'@SUM(A1:A2)")
      end
    end

    context "when the cell is an ordinary value" do
      it "returns the cell unchanged" do
        expect(described_class.sanitize_cell("Groceries")).to eq("Groceries")
      end
    end
  end
end

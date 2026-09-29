require "rails_helper"

RSpec.describe Transactions::Bulk::UpdateFromCsv, type: :interactor do
  subject { described_class.for(csv_rows: csv_rows) }

  let(:csv_rows) { CSV.parse(csv_content, headers: true) }

  context "when a row has a recognized attribute column" do
    let!(:transaction) { create(:transaction, category: "Old category") }
    let(:csv_content) do
      <<~CSV
        code,category
        #{transaction.code},New category
      CSV
    end

    it "updates the transaction's attribute" do
      subject

      expect(transaction.reload.category).to eq("New category")
    end
  end

  context "when a row has every recognized attribute column populated" do
    let!(:transaction) do
      create(:transaction, amount: 10, category: "Old", description: "Old desc", payment_method: "cash", occurred_at: "2024-01-01 10:00:00")
    end
    let(:csv_content) do
      <<~CSV
        code,amount,category,description,payment_method,occurred_at
        #{transaction.code},-25.50,Groceries,Weekly shop,credit_card,2024-02-02 11:00:00
      CSV
    end

    it "updates every recognized attribute" do
      subject
      transaction.reload

      expect(transaction.amount).to eq(-25.50)
      expect(transaction.category).to eq("Groceries")
      expect(transaction.description).to eq("Weekly shop")
      expect(transaction.payment_method).to eq("credit_card")
      expect(transaction.occurred_at).to eq(Time.zone.parse("2024-02-02 11:00:00"))
    end
  end

  context "when a row leaves some recognized columns blank" do
    let!(:transaction) { create(:transaction, amount: 10, category: "Groceries", description: "Untouched") }
    let(:csv_content) do
      <<~CSV
        code,amount,category,description
        #{transaction.code},-99,,
      CSV
    end

    it "only updates the columns with a value, leaving the others as they were" do
      subject
      transaction.reload

      expect(transaction.amount).to eq(-99)
      expect(transaction.category).to eq("Groceries")
      expect(transaction.description).to eq("Untouched")
    end
  end

  context "when the CSV has no code column" do
    let(:csv_content) do
      <<~CSV
        category
        Groceries
      CSV
    end

    it "raises InvalidCsvColumnsError without updating anything" do
      expect { subject }.to raise_error(Transactions::Errors::InvalidCsvColumnsError)
    end
  end

  context "when the CSV has no recognized attribute column" do
    let(:csv_content) do
      <<~CSV
        code
        txn_01
      CSV
    end

    it "raises InvalidCsvColumnsError" do
      expect { subject }.to raise_error(Transactions::Errors::InvalidCsvColumnsError)
    end
  end

  context "when the CSV has an unrecognized column" do
    let(:csv_content) do
      <<~CSV
        code,category,not_a_real_column
        txn_01,Groceries,oops
      CSV
    end

    it "raises InvalidCsvColumnsError" do
      expect { subject }.to raise_error(Transactions::Errors::InvalidCsvColumnsError)
    end
  end

  context "when one row in the middle of the CSV fails" do
    let!(:first_transaction) { create(:transaction, category: "Old") }
    let!(:second_transaction) { create(:transaction, category: "Old") }
    let(:csv_content) do
      <<~CSV
        code,category
        #{first_transaction.code},New
        txn_does_not_exist,New
        #{second_transaction.code},New
      CSV
    end

    it "rolls back every row, leaving all transactions unchanged" do
      expect { subject }.to raise_error(Transactions::Errors::BulkUpdateRowError)

      expect(first_transaction.reload.category).to eq("Old")
      expect(second_transaction.reload.category).to eq("Old")
    end

    it "reports which row failed and why" do
      expect { subject }.to raise_error(Transactions::Errors::BulkUpdateRowError) do |error|
        expect(error.details).to include(code: "txn_does_not_exist")
      end
    end
  end

  context "when a row has a value that fails validation, such as an unrecognized payment method" do
    let!(:transaction) { create(:transaction, payment_method: "cash") }
    let(:csv_content) do
      <<~CSV
        code,payment_method
        #{transaction.code},not_a_real_method
      CSV
    end

    it "rolls back and reports the failing row instead of raising a raw ArgumentError" do
      expect { subject }.to raise_error(Transactions::Errors::BulkUpdateRowError) do |error|
        expect(error.details).to include(code: transaction.code)
      end
      expect(transaction.reload.payment_method).to eq("cash")
    end
  end
end

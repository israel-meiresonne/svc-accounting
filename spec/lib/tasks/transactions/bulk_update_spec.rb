require "rails_helper"

RSpec.describe "transactions:bulk_update", type: :rake do
  subject { Rake::Task["transactions:bulk_update"].execute(task_arguments) }

  let(:file_path) { Rails.root.join("tmp", "bulk_update_spec_fixture.csv").to_s }
  let(:task_arguments) { Rake::TaskArguments.new(%i[file_path], [ file_path ]) }
  let!(:transaction) { create(:transaction, category: "Old category") }

  let(:csv_content) do
    <<~CSV
      code,category
      #{transaction.code},New category
    CSV
  end

  before { File.write(file_path, csv_content) }
  after { FileUtils.rm_f(file_path) }

  it "updates the transactions described by the CSV" do
    subject

    expect(transaction.reload.category).to eq("New category")
  end

  context "when a row fails" do
    let(:csv_content) do
      <<~CSV
        code,category
        txn_does_not_exist,New category
      CSV
    end

    it "raises BulkUpdateRowError without updating anything" do
      expect { subject }.to raise_error(Transactions::Errors::BulkUpdateRowError)
    end
  end
end

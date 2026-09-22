require "rails_helper"

RSpec.describe "transactions:csv:format", type: :rake do
  subject { Rake::Task["transactions:csv:format"].execute(task_arguments) }

  let!(:user) { create(:user) }
  let(:output_directory) { Transactions::Csv::Format::OutputPath::DIRECTORY }
  let(:file_path) { Rails.root.join("tmp", "format_csv_spec_fixture.csv").to_s }
  let(:user_code) { user.code }
  let(:task_arguments) do
    Rake::TaskArguments.new(%i[user_code provider file_path], [ user_code, "revolut", file_path ])
  end

  let(:csv_content) do
    <<~CSV
      Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance
      Card Payment,Current,2024-01-01 10:00:00,2024-01-01 10:00:05,Tesco Store,-12.50,0.00,EUR,COMPLETED,100.00
    CSV
  end

  before do
    FileUtils.rm_rf(output_directory)
    File.write(file_path, csv_content)
  end

  after do
    FileUtils.rm_rf(output_directory)
    FileUtils.rm_f(file_path)
  end

  it "writes the formatted CSV to the expected output path with the expected row count and values" do
    subject

    output_file = output_directory.join("01-formatted-from-revolut.csv")
    rows = CSV.read(output_file, headers: true)

    expect(rows.headers).to eq(Transactions::Csv::Format::OUTPUT_COLUMNS.map(&:to_s))
    expect(rows.size).to eq(1)
    expect(rows.first.to_h).to include(
      "occurred_at" => "2024-01-01 10:00:05",
      "amount" => "-12.50",
      "currency" => "EUR",
      "payment_method" => "credit_card",
      "description" => "Tesco Store"
    )
  end

  context "with an unknown user_code" do
    let(:user_code) { "usr_does_not_exist" }

    it "raises ActiveRecord::RecordNotFound" do
      expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

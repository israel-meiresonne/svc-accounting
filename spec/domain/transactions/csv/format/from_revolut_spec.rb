require "rails_helper"

RSpec.describe Transactions::Csv::Format::FromRevolut, type: :interactor do
  subject { described_class.for(user: user, csv_rows: csv_rows) }

  let!(:user) { create(:user) }

  def revolut_row(overrides = {})
    {
      "Type" => "Card Payment",
      "Product" => "Current",
      "Started Date" => "2024-01-01 10:00:00",
      "Completed Date" => "2024-01-01 10:00:05",
      "Description" => "Tesco Store",
      "Amount" => "-12.50",
      "Fee" => "0.00",
      "Currency" => "EUR",
      "State" => "COMPLETED",
      "Balance" => "100.00"
    }.merge(overrides)
  end

  def csv_table(rows, headers: described_class::EXPECTED_COLUMNS)
    csv_string = CSV.generate do |csv|
      csv << headers
      rows.each { |row| csv << headers.map { |header| row.fetch(header) } }
    end

    CSV.parse(csv_string, headers: true)
  end

  context "with a plain card payment whose merchant matches no override or existing user" do
    let(:csv_rows) { csv_table([ revolut_row ]) }

    it "defaults the counterparty to the merchant name as a company, with a blank category" do
      expect(subject).to eq(
        [
          {
            occurred_at: "2024-01-01 10:00:05",
            amount: "-12.50",
            currency: "EUR",
            payment_method: "credit_card",
            category: "",
            description: "Tesco Store",
            account: "Revolut Current EUR",
            counterparty_type: "company",
            counterparty_name: "Tesco Store",
            counterparty_email: ""
          }
        ]
      )
    end
  end

  context "with a REVERTED row" do
    let(:csv_rows) { csv_table([ revolut_row("State" => "REVERTED"), revolut_row ]) }

    it "drops the reverted row" do
      expect(subject.size).to eq(1)
      expect(subject.first[:description]).to eq("Tesco Store")
    end
  end

  context "with a PENDING row" do
    let(:csv_rows) { csv_table([ revolut_row.merge("State" => "PENDING"), revolut_row ]) }

    it "drops the pending row" do
      expect(subject.size).to eq(1)
      expect(subject.first[:description]).to eq("Tesco Store")
    end
  end

  context "with an Exchange row that has a fee" do
    let(:csv_rows) do
      csv_table([ revolut_row(
        "Type" => "Exchange",
        "Description" => "Exchanged to USD",
        "Amount" => "100.00",
        "Fee" => "1.00"
      ) ])
    end

    it "splits into two rows sharing the same occurred_at" do
      expect(subject.map { |row| row[:amount] }).to eq([ "100.00", "-1.00" ])
      expect(subject.map { |row| row[:occurred_at] }.uniq).to eq([ "2024-01-01 10:00:05" ])
    end
  end

  context "with a Charge row" do
    let(:csv_rows) do
      csv_table([ revolut_row(
        "Type" => "Charge",
        "Description" => "Monthly fee",
        "Amount" => "0.00",
        "Fee" => "2.00"
      ) ])
    end

    it "emits a single row using the negated fee as the amount" do
      expect(subject.size).to eq(1)
      expect(subject.first[:amount]).to eq("-2.00")
    end
  end

  context "with a same-timestamp, same-currency, opposite-amount pair" do
    let(:csv_rows) do
      csv_table([
        revolut_row("Description" => "Pocket Withdrawal", "Amount" => "-20.00"),
        revolut_row("Description" => "Pocket Top-up", "Amount" => "20.00")
      ])
    end

    it "categorizes both rows as Transfers with the acting user as counterparty, without resolving category" do
      expect(Transactions::Csv::Format::ResolveCounterparty).not_to receive(:for)
      expect(Transactions::Csv::Format::AssignCategory).not_to receive(:for)

      expect(subject.map { |row| row[:category] }).to eq(%w[Transfers Transfers])
      expect(subject.map { |row| row[:counterparty_name] }).to eq([ user.display_name, user.display_name ])
      expect(subject.map { |row| row[:counterparty_type] }).to eq([ user.type, user.type ])
    end
  end

  context "with two unrelated rows that both happen to have a zero Amount, same timestamp and currency" do
    let(:csv_rows) do
      csv_table([
        revolut_row("Type" => "Charge", "Description" => "Card Delivery Fee", "Amount" => "0.00", "Fee" => "6.99"),
        revolut_row("Type" => "Charge", "Description" => "Card Issuance Fee", "Amount" => "0.00", "Fee" => "5.99")
      ])
    end

    it "does not treat a coincidental zero-amount match as an internal-account-transfer pair" do
      expect(subject.map { |row| row[:category] }).to eq([ "", "" ])
      expect(subject.map { |row| row[:counterparty_type] }).to eq(%w[company company])
    end
  end

  context "with an Exchange row that is not part of a zero-sum pair (a cross-currency conversion)" do
    let(:csv_rows) do
      csv_table([ revolut_row("Type" => "Exchange", "Description" => "Exchanged to USD", "Amount" => "53.28") ])
    end

    it "categorizes it as Transfers with the acting user as counterparty, not a fake company name" do
      expect(Transactions::Csv::Format::ResolveCounterparty).not_to receive(:for)

      expect(subject.first[:category]).to eq("Transfers")
      expect(subject.first[:counterparty_name]).to eq(user.display_name)
      expect(subject.first[:counterparty_type]).to eq(user.type)
    end
  end

  context "with a Revolut Bank UAB row that is not part of a zero-sum pair" do
    let(:csv_rows) { csv_table([ revolut_row("Description" => "Revolut Bank UAB", "Amount" => "-5.00") ]) }

    it "categorizes it as Transfers with the known entity as counterparty, defaulting to type company" do
      expect(subject.first[:category]).to eq("Transfers")
      expect(subject.first[:counterparty_name]).to eq("Revolut Bank UAB")
      expect(subject.first[:counterparty_type]).to eq("company")
    end
  end

  context "with a Revolut Bank UAB row when that exact name already exists as a non-company user" do
    let!(:revolut_entity) { create(:contact, first_name: "Revolut Bank", last_name: "UAB") }
    let(:csv_rows) { csv_table([ revolut_row("Description" => "Revolut Bank UAB", "Amount" => "-5.00") ]) }

    it "uses that user's real type instead of defaulting to company" do
      expect(subject.first[:counterparty_name]).to eq("Revolut Bank UAB")
      expect(subject.first[:counterparty_type]).to eq("contact")
    end
  end

  context "with a non-internal-transfer row whose counterparty must be resolved before its category" do
    let!(:merchant) { create(:contact, first_name: "Jane", last_name: "Merchant") }
    let!(:prior_account) { create(:account, user: user) }
    let!(:prior_transaction) do
      create(:transaction, account: prior_account, counterparty: merchant, description: "To Jane Merchant",
                            category: "Groceries")
    end
    let(:csv_rows) { csv_table([ revolut_row("Description" => "To Jane Merchant") ]) }

    it "resolves the counterparty and then looks up the matching category" do
      expect(subject.first[:counterparty_name]).to eq("Jane Merchant")
      expect(subject.first[:counterparty_type]).to eq("contact")
      expect(subject.first[:category]).to eq("Groceries")
    end
  end

  context "with a description matching a counterparty override for a person name variant" do
    let(:csv_rows) { csv_table([ revolut_row("Description" => "Payment from MEIRESONNE ANNE-MARIE") ]) }

    it "normalizes it to the canonical name from the override config, without needing an existing user" do
      expect(subject.first[:counterparty_name]).to eq("Anne-Marie Meiresonne")
      expect(subject.first[:counterparty_type]).to eq("contact")
    end
  end

  context "with a description matching a counterparty override for a company name variant" do
    let(:csv_rows) { csv_table([ revolut_row("Description" => "Uab Barbora Akropolisx500") ]) }

    it "normalizes it to the canonical company name" do
      expect(subject.first[:counterparty_name]).to eq("Barbora")
      expect(subject.first[:counterparty_type]).to eq("company")
    end
  end

  context "with a description matching a person-name override who is also a real app user" do
    let!(:israel) { create(:user, first_name: "Israel", last_name: "Meiresonne") }
    let(:csv_rows) { csv_table([ revolut_row("Description" => "Payment from MEIRESONNE ISRAEL") ]) }

    it "uses that user's real type instead of the override config's default" do
      expect(subject.first[:counterparty_name]).to eq("Israel Meiresonne")
      expect(subject.first[:counterparty_type]).to eq("user")
    end
  end

  context "with a description that would collide with a shorter override pattern" do
    let(:csv_rows) { csv_table([ revolut_row("Description" => "Bolt Food") ]) }

    it "matches the more specific override rather than the generic Bolt entry" do
      expect(subject.first[:counterparty_name]).to eq("Bolt Food")
    end
  end

  context "with an unrecognized Type" do
    let(:csv_rows) { csv_table([ revolut_row("Type" => "Some New Type") ]) }

    it "raises InvalidCsvColumnsError" do
      expect { subject }.to raise_error(Transactions::Errors::InvalidCsvColumnsError)
    end
  end

  context "with a CSV missing an expected column" do
    let(:csv_rows) do
      CSV.parse(CSV.generate { |csv| csv << (described_class::EXPECTED_COLUMNS - [ "Balance" ]) }, headers: true)
    end

    it "raises InvalidCsvColumnsError before processing any row" do
      expect(Transactions::Csv::Format::ResolveCounterparty).not_to receive(:for)

      expect { subject }.to raise_error(Transactions::Errors::InvalidCsvColumnsError)
    end
  end

  context "with a split fee row alongside a plain row" do
    let(:csv_rows) do
      csv_table([
        revolut_row("Description" => "First Row"),
        revolut_row("Type" => "Exchange", "Description" => "Second Row", "Amount" => "30.00", "Fee" => "3.00"),
        revolut_row("Description" => "Third Row")
      ])
    end

    it "preserves input order with a split row's second half immediately after its first" do
      expect(subject.map { |row| row[:description] }).to eq(
        [ "First Row", "Second Row", "Second Row", "Third Row" ]
      )
      expect(subject.map { |row| row[:amount] }).to eq(
        [ "-12.50", "30.00", "-3.00", "-12.50" ]
      )
    end

    it "always sets non-blank occurred_at, amount, currency, description and payment_method" do
      subject.each do |row|
        expect(row[:occurred_at]).to be_present
        expect(row[:amount]).to be_present
        expect(row[:currency]).to be_present
        expect(row[:description]).to be_present
        expect(row[:payment_method]).to be_present
      end
    end
  end
end

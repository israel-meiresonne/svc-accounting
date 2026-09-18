require "rails_helper"

RSpec.describe Transaction, type: :model do
  context "with factory" do
    it "creates a valid transaction" do
      expect(build(:transaction)).to be_valid
    end

    it "assigns a txn_-prefixed code on create" do
      expect(create(:transaction).code).to match(/\Atxn_[0-9A-Z]{26}\z/)
    end
  end

  context "with associations" do
    it "belongs to an account" do
      account = create(:account)
      transaction = create(:transaction, account: account)

      expect(transaction.account).to eq(account)
    end

    it "belongs to a counterparty" do
      counterparty = create(:contact)
      transaction = create(:transaction, counterparty: counterparty)

      expect(transaction.counterparty).to eq(counterparty)
    end
  end

  context "with validations" do
    it "requires occurred_at" do
      expect(build(:transaction, occurred_at: nil)).not_to be_valid
    end

    it "requires currency" do
      expect(build(:transaction, currency: nil)).not_to be_valid
    end

    context "with #currency_matches_account" do
      it "is valid when currency matches the account's currency" do
        account = create(:account, currency: "usd")

        expect(build(:transaction, account: account, currency: "usd")).to be_valid
      end

      it "is invalid when currency differs from the account's currency" do
        account = create(:account, currency: "usd")

        expect(build(:transaction, account: account, currency: "eur")).not_to be_valid
      end
    end
  end

  context "with enums" do
    it "has the payment_method values" do
      expect(described_class.payment_methods).to eq(
        "cash" => "cash",
        "credit_card" => "credit_card",
        "bank_transfer" => "bank_transfer",
        "other" => "other",
      )
    end
  end

  context "with scopes" do
    let!(:account) { create(:account) }
    let!(:in_range_transaction) { create(:transaction, account: account, occurred_at: Date.new(2026, 6, 15).noon) }
    let!(:before_range_transaction) { create(:transaction, account: account, occurred_at: Date.new(2026, 5, 1).noon) }
    let!(:after_range_transaction) { create(:transaction, account: account, occurred_at: Date.new(2026, 7, 1).noon) }

    context "with .in_range" do
      it "returns only transactions occurring within the given date range" do
        result = described_class.in_range(Date.new(2026, 6, 1), Date.new(2026, 6, 30))

        expect(result).to contain_exactly(in_range_transaction)
      end
    end
  end

  context "with #assign_dedup_hash" do
    let(:counterparty) { create(:contact) }
    let(:occurred_at) { Time.zone.local(2026, 6, 15, 10, 0, 0) }
    let(:base_attributes) { { occurred_at: occurred_at, amount: 42, currency: "usd", counterparty: counterparty } }

    it "produces the same hash for identical inputs" do
      first = build(:transaction, **base_attributes)
      second = build(:transaction, **base_attributes)
      first.valid?
      second.valid?

      expect(first.dedup_hash).to eq(second.dedup_hash)
    end

    it "changes when the date changes" do
      base = build(:transaction, **base_attributes)
      changed = build(:transaction, **base_attributes.merge(occurred_at: occurred_at + 1.day))
      base.valid?
      changed.valid?

      expect(changed.dedup_hash).not_to eq(base.dedup_hash)
    end

    it "changes when the amount changes" do
      base = build(:transaction, **base_attributes)
      changed = build(:transaction, **base_attributes.merge(amount: 43))
      base.valid?
      changed.valid?

      expect(changed.dedup_hash).not_to eq(base.dedup_hash)
    end

    it "changes when the currency changes" do
      eur_account = create(:account, currency: "eur")
      base = build(:transaction, **base_attributes)
      changed = build(:transaction, **base_attributes.merge(account: eur_account, currency: "eur"))
      base.valid?
      changed.valid?

      expect(changed.dedup_hash).not_to eq(base.dedup_hash)
    end

    it "changes when the counterparty changes" do
      base = build(:transaction, **base_attributes)
      changed = build(:transaction, **base_attributes.merge(counterparty: create(:contact)))
      base.valid?
      changed.valid?

      expect(changed.dedup_hash).not_to eq(base.dedup_hash)
    end

    it "is not affected by the description" do
      base = build(:transaction, **base_attributes.merge(description: "first entry"))
      changed = build(:transaction, **base_attributes.merge(description: "second entry, slightly different"))
      base.valid?
      changed.valid?

      expect(changed.dedup_hash).to eq(base.dedup_hash)
    end
  end
end

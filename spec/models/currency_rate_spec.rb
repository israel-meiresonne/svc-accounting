require "rails_helper"

RSpec.describe CurrencyRate, type: :model do
  context "with factory" do
    it "creates a valid currency rate" do
      expect(build(:currency_rate)).to be_valid
    end
  end

  context "with validations" do
    it "requires left" do
      expect(build(:currency_rate, left: nil)).not_to be_valid
    end

    it "requires right" do
      expect(build(:currency_rate, right: nil)).not_to be_valid
    end

    it "requires rate" do
      expect(build(:currency_rate, rate: nil)).not_to be_valid
    end

    it "requires a unique combination of left and right" do
      create(:currency_rate, left: "usd", right: "eur")
      duplicate = build(:currency_rate, left: "usd", right: "eur")

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end

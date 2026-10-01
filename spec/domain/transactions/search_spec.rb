require "rails_helper"

RSpec.describe Transactions::Search, type: :interactor do
  subject { described_class.for(**params).map(&:code) }

  let!(:user) { create(:user) }
  let!(:account) { create(:account, user: user) }
  let!(:rent) { create(:transaction, account: account, category: "Rent") }
  let!(:groceries) { create(:transaction, account: account, category: "Groceries") }
  let!(:transfer) { create(:transaction, account: account, category: "Transfers") }
  let(:filters) { {} }
  let(:params) { { user: user, from: nil, to: nil, filters: filters, sort: nil, order: nil, page: 1, per_page: 50 } }

  context "with one included category" do
    let(:filters) { { included_categories: [ "Rent" ] } }

    it "returns only that category's transactions" do
      expect(subject).to contain_exactly(rent.code)
    end
  end

  context "with several included categories" do
    let(:filters) { { included_categories: %w[Rent Groceries] } }

    it "returns the union of those categories" do
      expect(subject).to contain_exactly(rent.code, groceries.code)
    end
  end

  [ nil, [] ].each do |blank_value|
    context "with included_categories set to #{blank_value.inspect}" do
      let(:filters) { { included_categories: blank_value } }

      it "returns every transaction" do
        expect(subject).to contain_exactly(rent.code, groceries.code, transfer.code)
      end
    end
  end
end

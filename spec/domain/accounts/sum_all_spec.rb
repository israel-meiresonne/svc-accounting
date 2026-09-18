require "rails_helper"

RSpec.describe Accounts::SumAll, type: :interactor do
  subject { described_class.for(**params) }

  let(:params) { { accounts: Account.where(id: [ usd_account.id, eur_account.id ]), currency: "usd" } }
  let!(:usd_account) { create(:account, currency: "usd", initial_balance: 100) }
  let!(:eur_account) { create(:account, currency: "eur", initial_balance: 80) }
  let!(:usd_to_eur) { create(:currency_rate, left: "usd", right: "eur", rate: 0.8) }

  it "sums accounts of different currencies converted into the target currency" do
    expect(subject.as_json).to eq(amount: "200.00", currency: "usd")
  end

  context "when the accounts relation is empty" do
    let(:params) { { accounts: Account.none, currency: "usd" } }

    it "returns a zero-amount result rather than nil" do
      expect(subject.as_json).to eq(amount: "0.00", currency: "usd")
    end
  end
end

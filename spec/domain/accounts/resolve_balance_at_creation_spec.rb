require "rails_helper"

RSpec.describe Accounts::ResolveBalanceAtCreation, type: :interactor do
  subject { described_class.for(account) }

  context "when balance_at_creation is set" do
    let(:account) { create(:account, initial_balance: nil, balance_at_creation: 500, currency: "usd") }
    let!(:income) { create(:transaction, account: account, amount: 200, currency: "usd") }
    let!(:expense) { create(:transaction, account: account, amount: -50, currency: "usd") }

    it "resolves initial_balance backward from balance_at_creation and the account's transactions" do
      subject

      expect(account.reload.initial_balance).to eq(350)
    end

    it "clears balance_at_creation" do
      subject

      expect(account.reload.balance_at_creation).to be_nil
    end
  end

  context "when balance_at_creation is already nil" do
    let(:account) { create(:account, initial_balance: 100, balance_at_creation: nil) }

    it "does not raise" do
      expect { subject }.not_to raise_error
    end

    it "does not change initial_balance" do
      expect { subject }.not_to change { account.reload.initial_balance }
    end
  end
end

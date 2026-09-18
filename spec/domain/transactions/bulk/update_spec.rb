require "rails_helper"

RSpec.describe Transactions::Bulk::Update, type: :interactor do
  subject { described_class.for(**params) }

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let!(:transaction) { create(:transaction, account: account, category: "food", payment_method: "cash", description: "old") }
  let(:params) { { user: user, transaction_codes: [ transaction.code ], attributes: attributes } }
  let(:attributes) { { category: "rent", payment_method: "bank_transfer", description: "new" } }

  it "updates the allowed attributes on the matching transactions" do
    subject

    expect(transaction.reload).to have_attributes(category: "rent", payment_method: "bank_transfer", description: "new")
  end

  it "returns the number of updated transactions" do
    expect(subject).to eq(1)
  end

  context "when an attribute is not bulk-editable" do
    let(:attributes) { { amount: 999 } }

    it "raises Transactions::Errors::InvalidBulkAttributesError" do
      expect { subject }.to raise_error(Transactions::Errors::InvalidBulkAttributesError)
    end

    it "carries the disallowed attribute names in the error details" do
      expect { subject }.to raise_error(having_attributes(details: { disallowed: [ "amount" ] }))
    end

    it "does not update anything" do
      expect { subject }.to raise_error(Transactions::Errors::InvalidBulkAttributesError)
      expect(transaction.reload.category).to eq("food")
    end
  end

  context "when the transaction belongs to another user" do
    let(:other_user) { create(:user) }
    let(:other_account) { create(:account, user: other_user) }
    let!(:other_transaction) { create(:transaction, account: other_account, category: "food") }
    let(:params) { { user: user, transaction_codes: [ other_transaction.code ], attributes: attributes } }

    it "affects zero rows" do
      expect(subject).to eq(0)
    end

    it "does not change the other user's transaction" do
      expect { subject }.not_to change { other_transaction.reload.category }
    end
  end
end

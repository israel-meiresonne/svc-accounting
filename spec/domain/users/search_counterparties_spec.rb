require "rails_helper"

RSpec.describe Users::SearchCounterparties, type: :interactor do
  subject { described_class.for(**params) }

  let!(:user) { create(:user) }
  let!(:account) { create(:account, user: user, currency: "usd") }
  let!(:contact) { create(:contact, first_name: "Searchable", last_name: "Contact") }
  let!(:company) { create(:company, company_name: "Searchable Company") }
  let(:params) { { user: user, query: "searchable" } }

  it "returns contact-type counterparties matching the query" do
    expect(subject).to include(contact)
  end

  it "returns company-type counterparties matching the query" do
    expect(subject).to include(company)
  end

  it "excludes records that do not match the query" do
    expect(subject).not_to include(create(:contact, first_name: "Other", last_name: "Person"))
  end

  context "when a user-type record has never transacted with the current user" do
    let!(:stranger) { create(:user, first_name: "Searchable", last_name: "Stranger") }

    it "is excluded from the results" do
      expect(subject).not_to include(stranger)
    end
  end

  context "when a user-type record is already a counterparty on the current user's transaction" do
    let!(:known_user) { create(:user, first_name: "Searchable", last_name: "Known") }
    let!(:transaction) { create(:transaction, account: account, counterparty: known_user) }

    it "is included in the results" do
      expect(subject).to include(known_user)
    end
  end

  context "when a user-type record is a counterparty on another user's transaction only" do
    let!(:other_account) { create(:account, currency: "usd") }
    let!(:foreign_user) { create(:user, first_name: "Searchable", last_name: "Foreign") }
    let!(:transaction) { create(:transaction, account: other_account, counterparty: foreign_user) }

    it "is excluded from the results" do
      expect(subject).not_to include(foreign_user)
    end
  end

  context "when more matches exist than the result limit" do
    let!(:extra_contacts) { create_list(:contact, 12, first_name: "Searchable") }

    it "returns at most ten records" do
      expect(subject.size).to eq(10)
    end
  end
end

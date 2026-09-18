require "rails_helper"

RSpec.describe "currencies:fetch_rates", type: :rake do
  subject { Rake::Task["currencies:fetch_rates"].execute }

  let!(:eur_account) { create(:account, currency: "eur") }
  let!(:gbp_account) { create(:account, currency: "gbp") }
  let!(:usd_account) { create(:account, currency: "usd") }
  let!(:chf_deleted_account) { create(:account, currency: "chf", deleted_at: Time.current) }

  it "fetches a rate for every active currency in use, excluding the central currency" do
    expect(Currencies::FetchRate).to receive(:for).with("eur")
    expect(Currencies::FetchRate).to receive(:for).with("gbp")
    expect(Currencies::FetchRate).not_to receive(:for).with("usd")
    expect(Currencies::FetchRate).not_to receive(:for).with("chf")

    subject
  end
end

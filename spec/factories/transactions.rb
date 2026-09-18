FactoryBot.define do
  factory :transaction do
    association :account
    association :counterparty, factory: :contact
    amount { 50 }
    currency { account.currency }
    payment_method { "cash" }
    occurred_at { Time.current }
  end
end

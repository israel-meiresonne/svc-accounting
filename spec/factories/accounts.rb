FactoryBot.define do
  factory :account do
    association :user
    name { "Checking" }
    currency { "usd" }
    initial_balance { 100 }
  end
end

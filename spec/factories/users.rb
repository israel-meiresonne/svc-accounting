FactoryBot.define do
  factory :user do
    type { "user" }
    first_name { "Jane" }
    last_name { "Doe" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    currency { "usd" }
  end

  factory :contact, class: "User" do
    type { "contact" }
    first_name { "John" }
    last_name { "Contact" }
  end

  factory :company, class: "User" do
    type { "company" }
    company_name { "Acme Inc" }
  end
end

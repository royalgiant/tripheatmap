FactoryBot.define do
  factory :offer do
    place { nil }
    saved_search { nil }
    offered_price_cents { 1 }
    discount_type { "MyString" }
    discount_value { "9.99" }
    perks { "" }
    personal_message { "MyText" }
    expires_at { "2025-12-28 16:51:53" }
    status { "MyString" }
    viewed_at { "2025-12-28 16:51:53" }
    accepted_at { "2025-12-28 16:51:53" }
  end
end

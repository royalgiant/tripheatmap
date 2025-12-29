FactoryBot.define do
  factory :saved_search do
    user
    location { "new york" }
    max_price_cents { 15000 }
    min_rating { 4.0 }
    price_range { "$$" }
    number_of_guests { 2 }

    trait :with_neighborhood do
      neighborhood { "downtown-new-york-ny" }
    end

    trait :with_dates do
      checkin_date { 7.days.from_now }
      checkout_date { 10.days.from_now }
    end
  end
end

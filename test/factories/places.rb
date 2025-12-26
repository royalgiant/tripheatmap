FactoryBot.define do
  factory :place do
    association :user
    neighborhood { nil }
    name { "Test Place" }
    place_type { "airbnb" }
    latitude { 40.7128 }
    longitude { -74.0060 }
    address { "123 Test St, New York, NY" }
    tags { "" }
    booking_url { "https://www.airbnb.com/rooms/12345" }
  end
end

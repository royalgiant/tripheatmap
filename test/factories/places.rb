FactoryBot.define do
  factory :place do
    neighborhood { nil }
    name { "MyString" }
    place_type { "MyString" }
    latitude { "9.99" }
    longitude { "9.99" }
    address { "MyString" }
    tags { "" }
  end
end

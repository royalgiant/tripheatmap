FactoryBot.define do
  factory :place do
    neighborhood { nil }
    name { "MyString" }
    place_type { "MyString" }
    lat { "9.99" }
    lon { "9.99" }
    address { "MyString" }
    tags { "" }
  end
end

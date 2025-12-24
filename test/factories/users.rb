FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    first_name { "Test" }
    last_name { "User" }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :oauth_user do
      provider { "google_oauth2" }
      sequence(:uid) { |n| "#{n}00000000000000000" }
      password { nil }
    end
  end
end

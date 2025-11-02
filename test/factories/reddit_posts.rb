FactoryBot.define do
  factory :reddit_post do
    post_id { "MyString" }
    subreddit { "MyString" }
    title { "MyString" }
    selftext { "MyText" }
    url { "MyString" }
    created_utc { "2025-11-01 21:01:21" }
    context { "MyString" }
    city { "MyString" }
    state { "MyString" }
    country { "MyString" }
    lat { 1.5 }
    lon { 1.5 }
    confidence { 1.5 }
    risk_level { "MyString" }
    status { "MyString" }
  end
end

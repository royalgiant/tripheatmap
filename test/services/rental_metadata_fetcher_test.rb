require "test_helper"

class RentalMetadataFetcherTest < ActiveSupport::TestCase
  test "extracts metadata from Airbnb JSON-LD" do
    html = <<-HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "VacationRental",
              "name": "Cozy Apartment",
              "description": "A lovely place to stay",
              "image": [
                "https://example.com/main.jpg",
                "https://example.com/gallery1.jpg",
                "https://example.com/gallery2.jpg"
              ],
              "aggregateRating": {
                "ratingValue": 4.8,
                "reviewCount": 120
              }
            }
          </script>
        </head>
      </html>
    HTML

    fetcher = RentalMetadataFetcher.new("https://www.airbnb.com/rooms/123")

    # Stub the fetch_html method to return our test HTML
    fetcher.define_singleton_method(:fetch_html) { html }

    metadata = fetcher.call

    assert_equal "Cozy Apartment", metadata[:title]
    assert_equal "A lovely place to stay", metadata[:description]
    assert_equal "https://example.com/main.jpg", metadata[:main_image]
    assert_equal ["https://example.com/gallery1.jpg", "https://example.com/gallery2.jpg"], metadata[:images]
    assert_equal 4.8, metadata[:rating]
    assert_equal 120, metadata[:review_count]
  end

  test "extracts metadata from OpenGraph tags as fallback" do
    html = <<-HTML
      <html>
        <head>
          <meta property="og:title" content="Nice Studio" />
          <meta property="og:description" content="Downtown location" />
          <meta property="og:image" content="https://example.com/og.jpg" />
        </head>
        <body>
          4 guests · 2 bedrooms · 3 beds · 1.5 baths
          4.9 stars
          200 reviews
        </body>
      </html>
    HTML

    fetcher = RentalMetadataFetcher.new("https://www.airbnb.com/rooms/456")
    fetcher.define_singleton_method(:fetch_html) { html }

    metadata = fetcher.call

    assert_equal "Nice Studio", metadata[:title]
    assert_equal "Downtown location", metadata[:description]
    assert_equal "https://example.com/og.jpg", metadata[:main_image]
    assert_equal 4, metadata[:guests]
    assert_equal 2, metadata[:bedrooms]
    assert_equal 3, metadata[:beds]
    assert_equal 1.5, metadata[:baths]
    assert_equal 4.9, metadata[:rating]
    assert_equal 200, metadata[:review_count]
  end

  test "returns empty hash on fetch failure" do
    fetcher = RentalMetadataFetcher.new("https://www.airbnb.com/rooms/999")
    fetcher.define_singleton_method(:fetch_html) { nil }

    metadata = fetcher.call
    assert_equal({}, metadata)
  end

  test "handles bot detection (429 status)" do
    # Test that we return empty hash when HTML fetch fails (like with 429)
    fetcher = RentalMetadataFetcher.new("https://www.vrbo.com/123")
    fetcher.define_singleton_method(:fetch_html) { nil }

    metadata = fetcher.call
    assert_equal({}, metadata)
  end

  test "normalizes metadata types correctly" do
    html = <<-HTML
      <html>
        <head>
          <meta property="og:title" content="  Spacious Loft  " />
        </head>
        <body>
          4 guests
          2.5 baths
        </body>
      </html>
    HTML

    fetcher = RentalMetadataFetcher.new("https://www.airbnb.com/rooms/789")
    fetcher.define_singleton_method(:fetch_html) { html }

    metadata = fetcher.call

    # String should be stripped
    assert_equal "Spacious Loft", metadata[:title]

    # Numbers should be proper types
    assert_equal 4, metadata[:guests]
    assert_instance_of Integer, metadata[:guests]

    assert_equal 2.5, metadata[:baths]
    assert_instance_of Float, metadata[:baths]
  end

  test "separates main_image from images array" do
    html = <<-HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "Apartment",
              "name": "Test",
              "image": [
                "https://example.com/first.jpg",
                "https://example.com/second.jpg",
                "https://example.com/third.jpg"
              ]
            }
          </script>
        </head>
      </html>
    HTML

    fetcher = RentalMetadataFetcher.new("https://www.airbnb.com/rooms/555")
    fetcher.define_singleton_method(:fetch_html) { html }

    metadata = fetcher.call

    assert_equal "https://example.com/first.jpg", metadata[:main_image]
    assert_equal ["https://example.com/second.jpg", "https://example.com/third.jpg"], metadata[:images]
    refute_includes metadata[:images], metadata[:main_image]
  end

  test "extracts amenities from page text" do
    html = <<-HTML
      <html>
        <head>
          <meta property="og:title" content="Test" />
        </head>
        <body>
          <div>Amenities include Wifi, Kitchen, and Pool. Also has Air conditioning and TV.</div>
        </body>
      </html>
    HTML

    fetcher = RentalMetadataFetcher.new("https://www.airbnb.com/rooms/111")
    fetcher.define_singleton_method(:fetch_html) { html }

    metadata = fetcher.call

    assert_includes metadata[:amenities], "Wifi"
    assert_includes metadata[:amenities], "Kitchen"
    assert_includes metadata[:amenities], "Pool"
    assert_includes metadata[:amenities], "Air conditioning"
    assert_includes metadata[:amenities], "TV"
  end
end

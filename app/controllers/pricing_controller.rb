class PricingController < ApplicationController
  def index
    # Fetch Stripe price IDs from credentials
    monthly_price_id = Rails.application.credentials.dig(Rails.env.to_sym, :stripe, :pricing, :monthly_price)
    annual_price_id = Rails.application.credentials.dig(Rails.env.to_sym, :stripe, :pricing, :annual_price)

    @plans = [
      {
        name: "Monthly",
        tagline: "Pay month-to-month",
        price: "$60",
        cadence: "per month",
        price_id: monthly_price_id,
        description: "List your rental where travelers search for vibrant neighborhoods. Reach ready-to-book guests researching their next trip.",
        highlights: [
          "Feature your property on Where to Stay guides",
          "Appear in neighborhood vibrancy searches",
          "Reach travelers beyond Airbnb & VRBO",
          "Direct booking link (skip platform fees)",
          # "Performance analytics dashboard",
          "30-day money-back guarantee"
        ],
        cta_label: "Get started",
        cta_path: current_user.present? ? purchase_checkouts_path(price_id: monthly_price_id) : signup_path
      },
      {
        name: "Annual (Save $470)",
        tagline: "Save with annual billing",
        price: "$250",
        cadence: "per year",
        price_id: annual_price_id,
        savings: "Save $470/year",
        description: "Same great features, billed annually. Best value for hosts committed to diversifying their booking channels.",
        highlights: [
          "Everything in Monthly",
          # "Priority placement in search results",
          # "Featured badge on your listing",
          "Annual billing saves $470",
          "Early adopter price, limited time only (grandfathered)",
          "30-day money-back guarantee"
        ],
        cta_label: "Get started",
        cta_path: current_user.present? ? purchase_checkouts_path(price_id: annual_price_id) : signup_path,
        featured: true
      }
    ]

    @faqs = [
      {
        question: "How is this different from Airbnb or VRBO?",
        answer: "We target travelers who research neighborhoods first, then book accommodations. Your listing gets exposure to ready-to-book travelers before they even open Airbnb or VRBO. Plus, you can include direct booking links to your Airbnb or VRBO listing(s)."
      },
      {
        question: "What's your refund policy?",
        answer: "We offer a 30-day money-back guarantee. If you're not satisfied for any reason within the first 30 days, we'll refund you in full. No questions asked."
      },
      {
        question: "Can I cancel anytime?",
        answer: "Yes. Cancel from your billing portal anytime with no penalties or cancellation fees."
      },
      {
        question: "What does \"grandfathered\" mean?",
        answer: "The prices you see are for early adopters. Prices will go up after the early adopter period ends. Early adopters will be grandfathered in at the price they signed up for."
      },
      {
        question: "Do you take a commission on bookings?",
        answer: "No. Unlike Airbnb and VRBO, we never take a cut of your bookings. You keep 100% of your revenue from guests booking directly with you all for the price of a monthly or annual plan."
      },
      {
        question: "What if my city isn't listed?",
        answer: "We're constantly adding cities and have added 75+ of the most popular and major cities in the USA. We're currently expanding abroad. If we're missing your city, <a href='mailto:donald@tripheatmap.com' class='text-blue-600 hover:text-blue-800 underline'>contact us</a> and we'll add it right away.".html_safe
      },
      {
        question: "How do travelers find my listing?",
        answer: "Travelers use our vibrancy scores (restaurant, bar, cafe density) to find the best neighborhoods for the type of trip they're planning. Your listing appears when they explore those neighborhoods, giving you exposure to highly motivated guests."
      },
      {
        question: "How are we better than agents or property managers for finding guests?",
        answer: "We use SEO to rank our data-driven neighborhood guides and vibrancy scores in search results. People researching for their next trip will find us AND YOU for accomodations. In short, we're like an SEO agency for your Airbnb or VRBO listing(s). Except our visitors are already highly motivated to book."
      }
    ]
  end
end

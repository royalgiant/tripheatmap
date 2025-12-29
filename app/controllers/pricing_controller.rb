class PricingController < ApplicationController
  def index
    # Fetch Stripe price IDs from credentials
    monthly_price_id = Rails.application.credentials.dig(Rails.env.to_sym, :stripe, :pricing, :monthly_price)
    annual_price_id = Rails.application.credentials.dig(Rails.env.to_sym, :stripe, :pricing, :annual_price)
    lifetime_price_id = Rails.application.credentials.dig(Rails.env.to_sym, :stripe, :pricing, :lifetime_host_price)

    @plans = [
      {
        name: "Lifetime (Early Adopter)",
        tagline: "One-time payment",
        price: "$120",
        cadence: "once",
        price_id: lifetime_price_id,
        tier: "basic",
        description: "Get your property discovered by travelers searching for the perfect neighborhood. One payment, lifetime visibility. Unlimited properties.",
        highlights: [
          "Get discovered on Google before travelers search Airbnb",
          "Get recommended by AI assistants (ChatGPT, Claude, Gemini)",
          "Show up when travelers search vibrant neighborhoods for their next stay",
          "Links to your Airbnb/VRBO listing included",
          "Costs less than 1 night's stay",
          "30-day money-back guarantee"
        ],
        cta_label: "Get started",
        cta_path: current_user.present? ? purchase_checkouts_path(price_id: lifetime_price_id) : signup_path
      },
      {
        name: "Monthly",
        tagline: "We only get paid if you get paid",
        price: "$60",
        cadence: "per month",
        price_id: monthly_price_id,
        tier: "leads",
        description: "Everything in Lifetime, plus direct access to hot leads actively searching your neighborhood. Turn browsers into bookers.",
        highlights: [
          "Everything in Lifetime",
          "Get notified when travelers save searches in your area",
          "Reach out first with exclusive deals before they book elsewhere",
          "Close motivated travelers searching your exact location",
          "Cancel anytime, no time limit refunds",
          "Risk-free: we only profit when you do"
        ],
        cta_label: "Get started",
        cta_path: current_user.present? ? purchase_checkouts_path(price_id: monthly_price_id) : signup_path,
        featured: true
      },
      {
        name: "Annual (Save $470)",
        tagline: "Best value for serious hosts",
        price: "$250",
        cadence: "per year",
        price_id: annual_price_id,
        tier: "leads",
        savings: "Save $470/year",
        description: "Same benefits as Monthly. Save 65% with annual billing. Perfect for hosts committed to capturing every booking opportunity.",
        highlights: [
          "Everything in Monthly",
          "Annual billing saves $470",
          "Early adopter price (grandfathered forever)",
          "Cancel anytime, no time limit refunds",
          "Risk-free: we only profit when you do"
        ],
        cta_label: "Get started",
        cta_path: current_user.present? ? purchase_checkouts_path(price_id: annual_price_id) : signup_path
      }
    ]

    @faqs = [
      {
        question: "How do travelers find my property?",
        answer: "We focus on ranking for neighborhood searches like 'best neighborhoods in Austin' or 'vibrant areas Seattle' on Google and other search engines. When travelers research where to stay, they can discover us—and your property—before they even open Airbnb or VRBO."
      },
      {
        question: "What's the refund policy?",
        answer: "Lifetime plan: 30-day money-back guarantee. Monthly/Annual plans: Unlimited refunds, cancel anytime. We only profit when you profit. If you're not getting value, you shouldn't pay—simple as that."
      },
      {
        question: "What makes Monthly/Annual different from Lifetime?",
        answer: "Lifetime gets you discovered on Google and AI assistants. Monthly/Annual gives you that PLUS direct access to hot leads. You get notified when travelers save searches in your area and can reach out first with deals before they book elsewhere. These are ready-to-book travelers, not browsers."
      },
      {
        question: "How good are these leads?",
        answer: "These are travelers who've already researched your neighborhood, filtered by price and rating, and saved their search. They're motivated and know exactly what they want. You just need to close them with a competitive offer before Airbnb or VRBO does."
      },
      {
        question: "Do AI assistants really recommend properties?",
        answer: "Yes. ChatGPT, Claude, Gemini, and Grok all scrape our neighborhood guides when travelers ask 'where should I stay in [city]?'. Your listing appears in their recommendations, giving you exposure to a growing channel that didn't recently exist and that traditional booking platforms ignore."
      },
      {
        question: "Do you take a commission on bookings?",
        answer: "Never. Unlike Airbnb (15-20% fees) and VRBO (10-15% fees), we never touch your bookings. You keep 100% of your revenue. We make money from subscriptions, not your hard-earned bookings."
      },
      {
        question: "What does \"grandfathered\" mean for Annual plans?",
        answer: "Early adopters lock in today's pricing forever, even when we raise prices later. If you sign up at $250/year, that's your rate for life unless you cancel—no price increases, ever."
      },
      {
        question: "Is this tax-deductible?",
        answer: "Yes, as a business expense for your rental property, TripHeatMap subscriptions are typically tax-deductible. This is marketing spend for your business, just like any other advertising cost. Check with your accountant to confirm based on your specific situation."
      },
      {
        question: "Why should hosts invest in marketing when they already spend on their properties?",
        answer: "Most hosts spend thousands on Instagram-worthy interiors but $0 on marketing. Beautiful properties don't book themselves. For less than one night's revenue per year, stop relying on Airbnb's algorithm and start owning your visibility."
      },
      {
        question: "What if my city isn't listed?",
        answer: "We've added 200+ major cities in the USA and are expanding abroad. Missing your city? <a href='mailto:donald@tripheatmap.com' class='text-blue-600 hover:text-blue-800 underline'>Email us</a> and we'll add it within 48 hours.".html_safe
      }
    ]
  end
end

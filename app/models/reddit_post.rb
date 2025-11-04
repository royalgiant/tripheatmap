class RedditPost < ApplicationRecord
  enum status: {
    pending: "pending",
    analyzed: "analyzed",
    skipped: "skipped"
  }

  validates :post_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :subreddit, presence: true
  validates :url, presence: true
  validates :status, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :analyzed, -> { where(status: "analyzed") }
  scope :skipped, -> { where(status: "skipped") }
  
  scope :with_neighborhood, -> { where.not(neighborhood: nil) }
  scope :without_neighborhood, -> { where(neighborhood: nil) }
  scope :with_city, -> { where.not(city: nil) }
  scope :without_city, -> { where(city: nil) }
  scope :in_country, ->(country) { where(country: country) }
  scope :in_city, ->(city) { where(city: city) }
  scope :in_neighborhood, ->(neighborhood) { where(neighborhood: neighborhood) }

  scope :safe, -> { where(risk_level: "safe") }
  scope :caution, -> { where(risk_level: "caution") }
  scope :dangerous, -> { where(risk_level: "dangerous") }
  scope :high_risk, -> { where("risk_score >= ?", 0.67) }
  scope :medium_risk, -> { where("risk_score >= ? AND risk_score < ?", 0.34, 0.67) }
  scope :low_risk, -> { where("risk_score < ?", 0.34) }

  scope :this_year, -> { where("created_utc >= ?", Time.current.beginning_of_year) }
  scope :this_month, -> { where("created_utc >= ?", Time.current.beginning_of_month) }
  scope :this_week, -> { where("created_utc >= ?", Time.current.beginning_of_week) }
  scope :recent, ->(days = 7) { where("created_utc >= ?", days.days.ago) }
  scope :since, ->(date) { where("created_utc >= ?", date) }
  scope :between_dates, ->(start_date, end_date) { where(created_utc: start_date..end_date) }

  scope :high_confidence, -> { where("confidence >= ?", 0.8) }
  scope :medium_confidence, -> { where("confidence >= ? AND confidence < ?", 0.5, 0.8) }
  scope :low_confidence, -> { where("confidence < ?", 0.5) }

  def risk_emoji
    case risk_level
    when "dangerous" then "🔴"
    when "caution" then "🟡"
    when "safe" then "🟢"
    else "⚪"
    end
  end

  def incident_emoji
    case incident_type
    when "police_bribery", "checkpoint_extortion" then "👮"
    when "theft", "armed_robbery", "pickpocket" then "💰"
    when "taxi_scam", "rental_scam" then "🚕"
    when "assault" then "⚠️"
    else "🚨"
    end
  end
end

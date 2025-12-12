class GeneratePlaceAiContentJob < ApplicationJob
  queue_as :default

  def perform(place_id)
    place = Place.find_by(id: place_id)
    return unless place
    return unless %w[hotel hostel].include?(place.place_type)

    # Skip if already has the essential AI-generated fields (rating and price_range)
    # Category, average_price, and image_url may legitimately be nil if OpenAI couldn't find them
    return if place.rating.present? && place.price_range.present? && place.average_price.present?

    content = AiContentGenerator.generate_place_content(
      place: place,
      neighborhood: place.neighborhood
    )

    if content && (content[:rating].present? || content[:price_range].present? || content[:category].present? || content[:average_price].present? || content[:image_url].present?)
      updates = {}
      updates[:rating] = content[:rating] if content[:rating].present?
      updates[:price_range] = content[:price_range] if content[:price_range].present?
      updates[:category] = content[:category] if content[:category].present?
      updates[:average_price] = content[:average_price] if content[:average_price].present?
      updates[:image_url] = content[:image_url] if content[:image_url].present?

      place.update_columns(updates)
      Rails.logger.info "Generated AI content for place: #{place.name} (ID: #{place.id})"
    else
      Rails.logger.warn "Failed to generate AI content for place: #{place.name} (ID: #{place.id})"
    end
  rescue => e
    Rails.logger.error "Error generating AI content for place ID #{place_id}: #{e.message}"
    raise # Re-raise to trigger Sidekiq retry
  end
end

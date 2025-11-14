module WhereToStay
  # Assigns neighborhood tags based on vibrancy + amenity density thresholds.
  class TagAssigner
    TAGS = {
      place_to_be: "Place to Be",
      remote_workers: "Remote Workers",
      foodies: "Foodies",
      nightlife: "Nightlife Lovers"
    }.freeze

    def initialize(thresholds = {})
      @thresholds = thresholds
    end

    def tags_for(vibrancy:, densities:)
      tags = []
      densities = densities.transform_keys(&:to_sym)

      if meets_threshold?(:vibrancy, vibrancy)
        tags << TAGS[:place_to_be]
      end

      if meets_threshold?(:cafes, densities[:cafes])
        tags << TAGS[:remote_workers]
      end

      if meets_threshold?(:restaurants, densities[:restaurants])
        tags << TAGS[:foodies]
      end

      if meets_threshold?(:bars, densities[:bars])
        tags << TAGS[:nightlife]
      end

      tags
    end

    private

    def meets_threshold?(key, value)
      threshold = @thresholds[key]
      return false if threshold.nil? || value.nil?

      value >= threshold
    end
  end
end

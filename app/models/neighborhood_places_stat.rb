class NeighborhoodPlacesStat < ApplicationRecord
  belongs_to :neighborhood

  def restaurant_count
    neighborhood.places.where(place_type: 'restaurant').count
  end

  def cafe_count
    neighborhood.places.where(place_type: 'cafe').count
  end

  def bar_count
    neighborhood.places.where(place_type: 'bar').count
  end

  def hotel_count
    neighborhood.places.where(place_type: 'hotel').count
  end

  def hostel_count
    neighborhood.places.where(place_type: 'hostel').count
  end

  def total_amenities
    restaurant_count + cafe_count + bar_count
  end

  def total_accommodations
    hotel_count + hostel_count
  end

  def vibrancy_index
    counts = amenity_counts
    total = counts.values.sum
    return 0 if total == 0

    area_sq_km = neighborhood.area_sq_km
    return 0 if area_sq_km.nil? || area_sq_km <= 0

    density_factor = calculate_density_factor(total, area_sq_km)
    diversity_factor = calculate_diversity_factor(counts)
    volume_factor = 1 - Math.exp(-total / 20.0)

    vibrancy = (
      (0.4 * density_factor) +
      (0.3 * volume_factor) +
      (0.3 * diversity_factor)
    ) * 10.0

    vibrancy.round(2)
  end

  def restaurants_vibrancy
    return 0.0 if neighborhood.area_sq_km.nil? || neighborhood.area_sq_km <= 0
    (restaurant_count.to_f / neighborhood.area_sq_km).round(3)
  end

  def cafes_vibrancy
    return 0.0 if neighborhood.area_sq_km.nil? || neighborhood.area_sq_km <= 0
    (cafe_count.to_f / neighborhood.area_sq_km).round(3)
  end

  def bars_vibrancy
    return 0.0 if neighborhood.area_sq_km.nil? || neighborhood.area_sq_km <= 0
    (bar_count.to_f / neighborhood.area_sq_km).round(3)
  end

  def avg_hotel_rating
    avg_rating('hotel')
  end

  def avg_hostel_rating
    avg_rating('hostel')
  end

  private

  def amenity_counts
    # Count all amenity types for vibrancy calculation
    # (matches original overpass_importer.rb logic)
    place_counts = neighborhood.places.group(:place_type).count

    {
      restaurant: place_counts['restaurant'] || 0,
      cafe: place_counts['cafe'] || 0,
      bar: place_counts['bar'] || 0,
      hotel: place_counts['hotel'] || 0,
      hostel: place_counts['hostel'] || 0,
      attraction: place_counts['attraction'] || 0,
      museum: place_counts['museum'] || 0,
      monument: place_counts['monument'] || 0,
      viewpoint: place_counts['viewpoint'] || 0,
      airport: place_counts['airport'] || 0,
      university: place_counts['university'] || 0,
      beach: place_counts['beach'] || 0,
      convention_center: place_counts['convention_center'] || 0,
      theme_park: place_counts['theme_park'] || 0,
      zoo: place_counts['zoo'] || 0,
      park: place_counts['park'] || 0
    }
  end

  def calculate_density_factor(total_amenities, area_sq_km)
    density = total_amenities.to_f / area_sq_km

    saturation = case area_sq_km
                 when 0...0.5 then 150.0
                 when 0.5...2.0 then 80.0
                 when 2.0...5.0 then 40.0
                 else 20.0
                 end

    [density / saturation, 1.0].min
  end

  def calculate_diversity_factor(counts)
    total = counts.values.sum.to_f
    return 0 if total == 0

    entropy = counts.values.reduce(0) do |sum, count|
      next sum if count == 0
      share = count / total
      sum - (share * Math.log(share))
    end

    max_entropy = Math.log(3)
    (entropy / max_entropy).round(3)
  end

  def avg_rating(place_type)
    ratings = neighborhood.places
      .where(place_type: place_type)
      .where.not(rating: nil)
      .pluck(:rating)

    return nil if ratings.empty?
    (ratings.sum / ratings.size.to_f).round(1)
  end
end

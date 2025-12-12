class ConventionCenterImporter
  attr_reader :api_url

  def initialize
    @api_url = 'https://overpass-api.de/api/interpreter'
  end

  def import(city_key)
    city_config = CityDataImporter.city_configs[city_key]
    unless city_config
      Rails.logger.error "City config not found for: #{city_key}"
      return
    end

    city_name = CityDataImporter::CITY_NAMES[city_key]
    unless city_name
      Rails.logger.error "City name not found for: #{city_key}"
      return
    end

    Rails.logger.info "=" * 80
    Rails.logger.info "Importing convention centers for #{city_name}..."
    Rails.logger.info "=" * 80

    # Get all neighborhoods for this city to determine containment
    neighborhoods = Neighborhood.where(city: city_name.downcase).to_a

    if neighborhoods.empty?
      Rails.logger.warn "No neighborhoods found for #{city_name}. Skipping convention center import."
      return
    end

    # Calculate city bounds from all neighborhoods
    bounds = calculate_city_bounds(neighborhoods)

    # Query Overpass API for convention centers
    query = build_convention_center_query(bounds)
    Rails.logger.info "Querying Overpass API for convention centers..."

    response = HTTParty.post(api_url, body: query, timeout: 60)

    unless response.success?
      Rails.logger.error "Overpass API request failed: #{response.code}"
      return
    end

    data = JSON.parse(response.body)
    elements = data['elements'] || []

    Rails.logger.info "Found #{elements.size} convention center results from OSM"

    imported_count = 0
    skipped_count = 0

    elements.each do |element|
      # Extract coordinates
      lat, lon = extract_coordinates(element)
      next unless lat && lon

      # Extract name
      name = element.dig('tags', 'name')
      next if name.blank? || name == 'Unnamed'

      # Find which neighborhood contains this convention center
      neighborhood = find_neighborhood_for_point(lat, lon, neighborhoods)

      unless neighborhood
        Rails.logger.debug "Convention center '#{name}' is outside all neighborhoods, skipping"
        skipped_count += 1
        next
      end

      # Check if convention center already exists
      existing = Place.find_by(
        name: name,
        place_type: 'convention_center',
        neighborhood_id: neighborhood.id
      )

      if existing
        Rails.logger.debug "Convention center already exists: #{name}"
        skipped_count += 1
        next
      end

      # Create new convention center
      place = Place.new(
        name: name,
        place_type: 'convention_center',
        lat: lat,
        lon: lon,
        neighborhood_id: neighborhood.id,
        city: city_name.downcase,
        country: city_config['country'] || 'United States',
        continent: neighborhood.continent,
        tags: element['tags'] || {}
      )

      if place.save
        Rails.logger.info "✅ Imported: #{name} (#{neighborhood.name})"
        imported_count += 1
      else
        Rails.logger.error "Failed to save convention center: #{name} - #{place.errors.full_messages.join(', ')}"
      end
    end

    Rails.logger.info "=" * 80
    Rails.logger.info "Convention center import complete for #{city_name}"
    Rails.logger.info "Imported: #{imported_count}, Skipped: #{skipped_count}"
    Rails.logger.info "=" * 80

    imported_count
  end

  private

  def calculate_city_bounds(neighborhoods)
    lats = []
    lons = []

    neighborhoods.each do |neighborhood|
      next unless neighborhood.geom

      # Get the envelope (bounding box) of the geometry
      result = ActiveRecord::Base.connection.select_one(
        "SELECT ST_XMin(geom::geometry) as min_lon,
                ST_XMax(geom::geometry) as max_lon,
                ST_YMin(geom::geometry) as min_lat,
                ST_YMax(geom::geometry) as max_lat
         FROM neighborhoods
         WHERE id = #{neighborhood.id}"
      )

      if result
        lats << result['min_lat'].to_f
        lats << result['max_lat'].to_f
        lons << result['min_lon'].to_f
        lons << result['max_lon'].to_f
      end
    end

    {
      min_lat: lats.min,
      max_lat: lats.max,
      min_lon: lons.min,
      max_lon: lons.max
    }
  end

  def build_convention_center_query(bounds)
    bbox = "#{bounds[:min_lat]},#{bounds[:min_lon]},#{bounds[:max_lat]},#{bounds[:max_lon]}"

    <<~QUERY
      [out:json][timeout:25];
      (
        node["tourism"="convention_center"](#{bbox});
        way["tourism"="convention_center"](#{bbox});
        relation["tourism"="convention_center"](#{bbox});
        node["amenity"="conference_centre"](#{bbox});
        way["amenity"="conference_centre"](#{bbox});
        relation["amenity"="conference_centre"](#{bbox});
      );
      out center tags;
    QUERY
  end

  def extract_coordinates(element)
    if element['type'] == 'node'
      [element['lat'], element['lon']]
    elsif element['center']
      [element['center']['lat'], element['center']['lon']]
    else
      nil
    end
  end

  def find_neighborhood_for_point(lat, lon, neighborhoods)
    point = "POINT(#{lon} #{lat})"

    neighborhoods.find do |neighborhood|
      next unless neighborhood.geom

      sql = ActiveRecord::Base.sanitize_sql_array([
        "SELECT ST_Contains(geom::geometry, ST_GeomFromText(?, 4326)) as contains
         FROM neighborhoods WHERE id = ?",
        point,
        neighborhood.id
      ])

      result = ActiveRecord::Base.connection.select_one(sql)
      result && result['contains'] == true
    end
  end
end

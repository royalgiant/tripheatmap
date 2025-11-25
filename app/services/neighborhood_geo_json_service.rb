class NeighborhoodGeoJsonService
  def self.call(city: nil, state: nil, include_geometry: false)
    new(city: city, state: state, include_geometry: include_geometry).call
  end

  def initialize(city:, state:, include_geometry:)
    @city = city&.downcase
    @state = state
    @include_geometry = include_geometry
  end

  def call
    # Execute raw SQL safely using ActiveRecord's sanitization
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_query, query_params])
    )

    # Return the pre-built JSON string
    result.first['geojson']
  end

  private

  def query_params
    {
      city: @city,
      state: @state,
      include_geometry: @include_geometry
    }
  end

  def sql_query
    # Note on Security:
    # We use named bind parameters (:city, :state) which are sanitized by ActiveRecord.
    # The boolean check for include_geometry is handled in Ruby before query construction.
    
    <<-SQL
      WITH target_neighborhoods AS (
        SELECT n.*
        FROM neighborhoods n
        WHERE 1=1
        #{@city ? "AND n.city = :city" : ""}
        #{@state ? "AND n.state = :state" : ""}
      ),
      rental_counts AS (
        SELECT neighborhood_id,
               COUNT(*) FILTER (WHERE place_type = 'airbnb') as airbnb_count,
               COUNT(*) FILTER (WHERE place_type = 'vrbo') as vrbo_count
        FROM places
        WHERE neighborhood_id IN (SELECT id FROM target_neighborhoods)
        AND place_type IN ('airbnb', 'vrbo')
        GROUP BY neighborhood_id
      )
      SELECT json_build_object(
        'type', 'FeatureCollection',
        'metadata', json_build_object(
          'count', COUNT(*),
          'include_geometry', :include_geometry
        ),
        'features', COALESCE(json_agg(
          json_build_object(
            'type', 'Feature',
            'geometry', #{@include_geometry ? 'ST_AsGeoJSON(n.geom)::json' : 'ST_AsGeoJSON(n.centroid)::json'},
            'properties', json_build_object(
              'id', n.id,
              'geoid', n.geoid,
              'name', n.name,
              'city', n.city,
              'county', n.county,
              'state', n.state,
              'population', n.population,
              'slug', n.slug,
              'restaurant_count', COALESCE(s.restaurant_count, 0),
              'cafe_count', COALESCE(s.cafe_count, 0),
              'bar_count', COALESCE(s.bar_count, 0),
              'hotel_count', COALESCE(s.hotel_count, 0),
              'hostel_count', COALESCE(s.hostel_count, 0),
              'total_accommodations', COALESCE(s.total_accommodations, 0),
              'airbnb_count', COALESCE(r.airbnb_count, 0),
              'vrbo_count', COALESCE(r.vrbo_count, 0),
              'total_amenities', (COALESCE(s.total_amenities, 0) + COALESCE(r.airbnb_count, 0) + COALESCE(r.vrbo_count, 0)),
              'vibrancy_index', COALESCE(s.vibrancy_index, 0)
            )
          )
        ), '[]'::json)
      ) as geojson
      FROM target_neighborhoods n
      LEFT JOIN neighborhood_places_stats s ON n.id = s.neighborhood_id
      LEFT JOIN rental_counts r ON n.id = r.neighborhood_id
    SQL
  end
end

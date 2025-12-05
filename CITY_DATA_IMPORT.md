# City Data Import Guide

This guide explains how to import neighborhood boundaries and places data for the vibrancy map.

## Quick Start

### Import Data for a Single City

```bash
# Full import (boundaries + places)
kamal app exec -i "bundle exec rake 'city:import[las vegas,true]'"
rake city:import[dallas]
bundle exec rake "city:import[dallas,true]"

# Or use the service directly
bin/rails runner "CityDataImporter.new('dallas').import_all"
```

### Import Data for All Cities

```bash
rake city:import_all
```

## Available Commands

### Rake Tasks

```bash
# Import all data (boundaries + places) for a specific city
rake city:import[CITY]
# Example: rake city:import[dallas]

# Import only boundaries
rake city:import_boundaries[CITY]

# Import only places data (requires boundaries to exist)
rake city:import_places[CITY]

# Enrich existing census tract names (only needed for old data)
rake city:enrich_names[CITY]
# Updates existing "Tract 9802" to "Oak Cliff" (new imports do this automatically)

# Import all cities
rake city:import_all

# Update places data for all cities (skip boundaries)
rake city:update_places

# Show statistics for a city
rake city:stats[CITY]

# List all supported cities and their data status
rake city:list
```

### Ruby Service

```ruby
# Import all data for a city (boundaries + OSM places + hotels/hostels)
CityDataImporter.new('dallas').import_all

# Import only boundaries
CityDataImporter.new('dallas', skip_places: true).import_all

# Import only places (OSM amenities + hotels/hostels)
CityDataImporter.new('dallas', skip_boundaries: true).import_all

# Import all cities
CityDataImporter.import_all_cities

# Import only places for all cities
CityDataImporter.import_all_cities(skip_boundaries: true)
```

### Sidekiq Jobs (for scheduled/background execution)

```ruby
# Queue a job to import a specific city
ImportCityDataJob.perform_async('dallas')

# Update places for all cities (OSM restaurants/bars/cafes)
UpdatePlacesJob.perform_async

# Update hotels/hostels for all cities (removes closed businesses, adds new ones via OSM)
UpdateHotelsJob.perform_async

# Full import for all cities
ImportAllCitiesJob.perform_async
```

## Supported Cities

| City | Key | Status |
|------|-----|--------|
| Dallas | `dallas` | Census tracts (no official neighborhoods) |
| Chicago | `chicago` | Official city neighborhoods available |
| Miami | `miami` | Official city neighborhoods available |
| Austin | `austin` | Census tracts (no official neighborhoods) |
| Sacramento | `sacramento` | Census tracts (no official neighborhoods) |
| Buenos Aires | `buenos aires` | Official barrios (neighborhoods) available |

## Data Sources

### Neighborhood Boundaries

1. **City-specific neighborhoods** (Chicago, Miami):
   - Fetched from city open data portals (GeoJSON)
   - Official neighborhood boundaries

2. **Census Tracts** (Dallas, Austin, Sacramento):
   - Fetched from US Census Bureau TIGER/Line API
   - Used as fallback when official neighborhoods unavailable

### Population Data

- Fetched from US Census Bureau API
- Used to calculate per-capita vibrancy metrics

### Places/Amenities Data

**OpenStreetMap (via Overpass API)**
- Counts: restaurants, cafes, bars, hotels, hostels
- Free, worldwide data source
- Used for both vibrancy index and accommodation listings

## Import Workflow

The import process follows these steps:

1. **Import Neighborhoods** (`NeighborhoodBoundaryImporter`)
   - Fetches GeoJSON boundaries
   - Parses geometries using PostGIS
   - Fetches population data from Census API
   - Saves to `neighborhoods` table

2. **Import Places Data** (`OverpassImporter`)
   - For each neighborhood:
     - Gets bounding box
     - Queries Overpass API for amenities AND accommodations
     - Counts restaurants, cafes, bars
     - Counts hotels, hostels
     - Calculates vibrancy index (0-10 scale)
     - Saves individual places to `places` table
     - Saves stats to `neighborhood_places_stats` table

## Scheduled Jobs (Cron)

Scheduled jobs are configured in `config/schedule.yml` and managed by Sidekiq-Cron.

### Active Schedules

- **Weekly Places Update** (Sunday 2 AM): Updates OSM places data (restaurants/bars/cafes) for all cities
- **Monthly Hotels Update** (26th at 2 AM): Updates hotels/hostels via OSM
- Other schedules are disabled by default

### Enable a Schedule

Edit `config/schedule.yml` and set `enabled: true` for the desired job:

```yaml
import_dallas_daily:
  enabled: true  # Change from false to true
```

Then reload Sidekiq-Cron schedules:

```ruby
# In Rails console
Sidekiq::Cron::Job.load_from_hash(YAML.load_file('config/schedule.yml'))
```

## Vibrancy Index Calculation

The vibrancy index (0-10 scale) combines **density**, **diversity**, and **volume** for a holistic score:

```ruby
vibrancy = (0.4 × density_factor) + (0.3 × volume_factor) + (0.3 × diversity_factor)
```

**Note**: Weights are balanced for census tracts (larger areas) - volume matters more than in compact city neighborhoods.

### 1. Density Factor (40% weight, 0-1 scale)
Amenities per km² with **adaptive saturation** based on neighborhood size:

| Area Size | Saturation Point | Use Case |
|-----------|------------------|----------|
| < 0.5 km² | 150/km² | Micro neighborhoods (NYC, SF) |
| 0.5-2 km² | 80/km² | Compact urban (Chicago, Miami) |
| 2-5 km² | 40/km² | Standard census tracts (Dallas) |
| 5+ km² | 20/km² | Large suburban areas |

**Example**:
- Manhattan micro-neighborhood (0.3 km², 60 amenities) → 60/0.3 = 200/km² → 200/150 = 1.0 (maxed)
- Dallas census tract (3 km², 17 amenities) → 17/3 = 5.67/km² → 5.67/40 = 0.14 density factor

### 2. Diversity Factor (30% weight, 0-1 scale)
Mix of restaurant/cafe/bar using Shannon entropy:
- 0.0 = All one type (e.g., 50 restaurants, 0 cafes, 0 bars)
- 1.0 = Evenly mixed (e.g., 17 restaurants, 16 cafes, 17 bars)
- Rewards balanced neighborhoods over single-purpose districts

### 3. Volume Factor (30% weight, 0-1 scale)
Absolute count with diminishing returns:
- `1 - e^(-total/20)`
- First 20 amenities matter most
- More important for census tracts since they're larger areas

### Example Scores

| Neighborhood | Area (km²) | Restaurants | Cafes | Bars | Vibrancy |
|--------------|-----------|-------------|-------|------|----------|
| Uptown       | 1.5       | 50          | 20    | 15   | ~9.2     |
| Oak Cliff    | 8.2       | 25          | 10    | 5    | ~5.8     |
| Suburbia     | 20        | 15          | 3     | 1    | ~2.4     |

This approach rewards neighborhoods with dense, diverse, walkable amenities - regardless of population.

## Examples

### Import Only Hotels/Hostels

To update accommodations, you use the general places import (which now includes hotels/hostels):

```ruby
# Import places (includes hotels/hostels)
CityDataImporter.new('prague', skip_boundaries: true, force: true).import_all
```

### Import Only OSM Places

The standard import now fetches everything in one go (Restaurants, Bars, Cafes, Hotels, Hostels).

```ruby
# Import everything
CityDataImporter.new('dallas', skip_boundaries: true, force: true).import_all
```

### Initial Setup for Dallas

```bash
# 1. Import neighborhood boundaries and population
# Automatically enriches names: "Oak Cliff", "Uptown", etc.
rake city:import_boundaries[dallas]

# 2. Import places data
rake city:import_places[dallas]

# 3. Check results
rake city:stats[dallas]
```

### Neighborhood Name Enrichment

For cities using census tracts (Dallas, Austin, Sacramento), the import automatically uses reverse geocoding to get actual neighborhood names like "Oak Cliff", "Uptown", "Deep Ellum" instead of generic "Tract 9802".

**How it works:**
- During census tract import, each tract's centroid is reverse geocoded using Nominatim (OpenStreetMap)
- Automatically respects API rate limits (1 request/second)
- Falls back to "Tract 9802" if geocoding fails
- This happens by default - no extra step required!

**For existing data:**
If you already imported tracts with generic names, you can enrich them:

```bash
# Update existing neighborhoods with better names
rake city:enrich_names[dallas]
```

**Note**: Chicago and Miami use official neighborhood boundaries and don't need enrichment.

### Update Places Data Weekly

```bash
# Update all cities
rake city:update_places

# Or just one city
rake city:import_places[dallas]
```

### Check Current Data Status

```bash
# List all cities
rake city:list

# Detailed stats for one city
rake city:stats[dallas]
```

### Manual Testing

```ruby
# Import one neighborhood for testing (OSM places including hotels)
neighborhood = Neighborhood.where(city: 'dallas').first
OverpassImporter.new.import_for_neighborhood(neighborhood)

# Check the result
stat = neighborhood.neighborhood_places_stat
puts "Restaurants: #{stat.restaurant_count}"
puts "Cafes: #{stat.cafe_count}"
puts "Bars: #{stat.bar_count}"
puts "Hotels: #{stat.hotel_count}"
puts "Hostels: #{stat.hostel_count}"
puts "Vibrancy: #{stat.vibrancy_index}"

# View individual hotels
hotels = Place.hotels.where(neighborhood_id: neighborhood.id)
hotels.first(5).each do |hotel|
  puts "#{hotel.name} - #{hotel.place_type}"
end
```

## Troubleshooting

### Overpass API Rate Limiting

If you get rate limit errors from Overpass API:

1. Reduce concurrent requests
2. Add delays between neighborhoods
3. Use a different Overpass instance (configurable in `OverpassImporter`)

### Missing Population Data

If neighborhoods show 0 vibrancy despite having amenities:

```ruby
# Check population
Neighborhood.where(city: 'Dallas').where(population: nil).count

# Re-run population fetch
fips = YAML.load_file('config/neighborhood_boundaries.yml')['dallas']
CensusPopulationService.new.update_neighborhood_populations(
  state_fips: fips['state_fips'],
  county_fips: fips['county_fips']
)
```

### Geometry Errors

If you get PostGIS/RGeo errors:

1. Ensure PostGIS extension is enabled: `bin/rails db:migrate`
2. Check for invalid geometries:

```ruby
Neighborhood.where.not(geom: nil).find_each do |n|
  unless n.geom.valid?
    puts "Invalid geometry: #{n.name}"
  end
end
```

## Working with Hotel/Hostel Data

### Querying Places

```ruby
# Get all hotels in a city
Place.hotels.joins(:neighborhood).where(neighborhoods: {city: 'prague'})

# Get all accommodations (hotels + hostels)
Place.accommodations.where(neighborhood_id: neighborhood.id)

# Get budget accommodations
Place.hostels.where(neighborhood_id: neighborhood.id)
```

### Neighborhood Stats

```ruby
neighborhood = Neighborhood.find_by(name: 'Montmartre', city: 'paris')
stat = neighborhood.neighborhood_places_stat

puts "Hotels: #{stat.hotel_count}"
puts "Hostels: #{stat.hostel_count}"
puts "Total accommodations: #{stat.total_accommodations}"

# Compare neighborhoods by hotel density
neighborhoods = Neighborhood.for_city('paris')
  .joins(:neighborhood_places_stat)
  .order('neighborhood_places_stats.hotel_count DESC')
  .limit(10)
```

### Best Neighborhoods Algorithm

Use hotel data to rank neighborhoods:

```ruby
def best_neighborhoods_for_tourists(city)
  Neighborhood.for_city(city)
    .joins(:neighborhood_places_stat)
    .where('neighborhood_places_stats.hotel_count > 0')
    .select('neighborhoods.*,
             neighborhood_places_stats.hotel_count,
             neighborhood_places_stats.vibrancy_index')
    .order(Arel.sql('
      (neighborhood_places_stats.hotel_count * 0.6) +
      (neighborhood_places_stats.vibrancy_index * 0.4) DESC
    '))
end
```

## Adding a New City

1. Add city configuration to `config/neighborhood_boundaries.yml`
2. Add city name to `CityDataImporter::CITY_NAMES`
3. If city has official neighborhoods, verify endpoint in config
4. Run import: `rake city:import[new_city]`

## Performance Notes

- **Boundaries import**: 30-60 seconds per city
- **OSM Places import**: 1-3 seconds per neighborhood (varies by Overpass API response time)
- **Full Dallas import**: ~10-15 minutes (300+ census tracts)
- **Full Paris import**: ~15-20 minutes

Use background jobs (Sidekiq) for production imports to avoid timeouts.

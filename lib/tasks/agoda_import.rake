namespace :agoda do
  desc "Import Agoda hotel metadata from Excel file URL and match to existing places"
  task :import_metadata, [:file_url] => :environment do |t, args|
    require 'roo'
    require 'faraday'
    require 'tempfile'

    file_url = args[:file_url] || ENV['FILE_URL'] || 'https://tripheatmap.s3.us-east-005.backblazeb2.com/agoda.xlsx'

    # Download the file
    puts "Downloading file from: #{file_url}"
    tempfile = nil

    begin
      response = Faraday.get(file_url)

      unless response.success?
        puts "❌ Error: Failed to download file (HTTP #{response.status})"
        exit 1
      end

      tempfile = Tempfile.new(['agoda_hotels', '.xlsx'])
      tempfile.binmode
      tempfile.write(response.body)
      tempfile.close

      file_path = tempfile.path
      puts "✓ File downloaded successfully (#{(response.body.bytesize / 1024.0 / 1024.0).round(2)} MB)"
      puts ""
    rescue => e
      puts "❌ Error downloading file: #{e.message}"
      tempfile&.close
      tempfile&.unlink
      exit 1
    end

    puts "=" * 80
    puts "AGODA METADATA IMPORT"
    puts "=" * 80
    puts "File: #{file_path}"
    puts "Started at: #{Time.current}"
    puts ""

    # Step 1: Enable pg_trgm extension for fuzzy matching
    puts "Step 1: Enabling pg_trgm extension for fuzzy name matching..."
    ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    puts "✓ pg_trgm extension enabled"
    puts ""

    # Step 2: Create temporary table
    puts "Step 2: Creating temporary table..."
    ActiveRecord::Base.connection.execute(<<~SQL)
      DROP TABLE IF EXISTS agoda_hotels_temp;
      CREATE TEMP TABLE agoda_hotels_temp (
        hotel_id TEXT,
        hotel_name TEXT,
        latitude DOUBLE PRECISION,
        longitude DOUBLE PRECISION,
        photo1 TEXT,
        photo2 TEXT,
        photo3 TEXT,
        photo4 TEXT,
        photo5 TEXT,
        overview TEXT,
        geog GEOGRAPHY(POINT, 4326)
      );
      CREATE INDEX idx_agoda_temp_geog ON agoda_hotels_temp USING GIST(geog);
      CREATE INDEX idx_agoda_temp_name ON agoda_hotels_temp USING gin(hotel_name gin_trgm_ops);
    SQL
    puts "✓ Temporary table created with spatial and text indexes"
    puts ""

    # Step 3: Load Excel file
    puts "Step 3: Loading Excel file (this may take a few minutes for large files)..."
    xlsx = Roo::Spreadsheet.open(file_path)
    total_rows = xlsx.last_row - 1 # Exclude header
    puts "✓ Found #{total_rows.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} rows"
    puts ""

    # Step 4: Import data in batches
    puts "Step 4: Importing data into temporary table..."
    batch_size = 10_000
    imported_count = 0
    skipped_count = 0

    (2..xlsx.last_row).each_slice(batch_size).with_index do |rows_slice, batch_index|
      values = rows_slice.map do |row_num|
        row = xlsx.row(row_num)

        # Map columns based on Excel structure:
        # [0] hotel_id, [1] hotel_name, [2] longitude, [3] latitude,
        # [4] photo1, [5] photo2, [6] photo3, [7] photo4, [8] photo5, [9] overview
        hotel_id = row[0]&.to_s
        hotel_name = row[1]&.to_s
        lon = row[2]  # Note: Excel has longitude first
        lat = row[3]  # Then latitude
        photo1 = row[4]&.to_s
        photo2 = row[5]&.to_s
        photo3 = row[6]&.to_s
        photo4 = row[7]&.to_s
        photo5 = row[8]&.to_s
        overview = row[9]&.to_s

        # Skip if missing critical fields
        if hotel_id.blank? || hotel_name.blank? || lat.nil? || lon.nil?
          skipped_count += 1
          next
        end

        # Escape strings for SQL
        hotel_id_escaped = ActiveRecord::Base.connection.quote(hotel_id)
        hotel_name_escaped = ActiveRecord::Base.connection.quote(hotel_name)
        photo1_escaped = ActiveRecord::Base.connection.quote(photo1)
        photo2_escaped = ActiveRecord::Base.connection.quote(photo2)
        photo3_escaped = ActiveRecord::Base.connection.quote(photo3)
        photo4_escaped = ActiveRecord::Base.connection.quote(photo4)
        photo5_escaped = ActiveRecord::Base.connection.quote(photo5)
        overview_escaped = ActiveRecord::Base.connection.quote(overview)

        "(#{hotel_id_escaped}, #{hotel_name_escaped}, #{lat}, #{lon}, #{photo1_escaped}, #{photo2_escaped}, #{photo3_escaped}, #{photo4_escaped}, #{photo5_escaped}, #{overview_escaped}, ST_SetSRID(ST_MakePoint(#{lon}, #{lat}), 4326)::geography)"
      end.compact

      if values.any?
        ActiveRecord::Base.connection.execute(<<~SQL)
          INSERT INTO agoda_hotels_temp
          (hotel_id, hotel_name, latitude, longitude, photo1, photo2, photo3, photo4, photo5, overview, geog)
          VALUES #{values.join(', ')}
        SQL
        imported_count += values.size
      end

      print "\r  Progress: #{((batch_index + 1) * batch_size * 100.0 / total_rows).round(1)}% (#{imported_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} imported)"
    end

    puts "\n✓ Import complete: #{imported_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} rows imported, #{skipped_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} rows skipped"
    puts ""

    # Step 5: Get count of places to match
    places_count = Place.where(place_type: ['hotel', 'hostel']).where("agoda_metadata IS NULL").count
    puts "Step 5: Found #{places_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} hotels/hostels without Agoda metadata"
    puts ""

    # Step 6: Match Stage 1 - Very close proximity (within 50m)
    puts "Step 6: Stage 1 - Matching by proximity (within 50 meters)..."
    stage1_result = ActiveRecord::Base.connection.execute(<<~SQL)
      WITH ranked_matches AS (
        SELECT DISTINCT ON (p.id)
          p.id as place_id,
          a.hotel_id,
          a.photo1,
          a.photo2,
          a.photo3,
          a.photo4,
          a.photo5,
          a.overview,
          ST_Distance(ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography, a.geog) as distance_meters
        FROM places p
        JOIN agoda_hotels_temp a ON ST_DWithin(
          ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography,
          a.geog,
          50
        )
        WHERE p.place_type IN ('hotel', 'hostel')
          AND p.agoda_metadata IS NULL
          AND p.latitude IS NOT NULL
          AND p.longitude IS NOT NULL
        ORDER BY p.id, distance_meters ASC
      )
      UPDATE places
      SET agoda_metadata = jsonb_build_object(
        'hotel_id', rm.hotel_id,
        'photo1', rm.photo1,
        'photo2', rm.photo2,
        'photo3', rm.photo3,
        'photo4', rm.photo4,
        'photo5', rm.photo5,
        'overview', rm.overview,
        'matched_by', 'proximity_50m',
        'distance_meters', rm.distance_meters
      )
      FROM ranked_matches rm
      WHERE places.id = rm.place_id
      RETURNING places.id;
    SQL
    stage1_count = stage1_result.count
    puts "✓ Stage 1 complete: #{stage1_count} places matched"
    puts ""

    # Step 7: Match Stage 2 - Fuzzy name + proximity (within 200m, name >60% similar)
    puts "Step 7: Stage 2 - Matching by fuzzy name + proximity (within 200m, >60% name similarity)..."
    stage2_result = ActiveRecord::Base.connection.execute(<<~SQL)
      WITH ranked_matches AS (
        SELECT DISTINCT ON (p.id)
          p.id as place_id,
          a.hotel_id,
          a.photo1,
          a.photo2,
          a.photo3,
          a.photo4,
          a.photo5,
          a.overview,
          ST_Distance(ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography, a.geog) as distance_meters,
          similarity(LOWER(p.name), LOWER(a.hotel_name)) as name_similarity
        FROM places p
        JOIN agoda_hotels_temp a ON ST_DWithin(
          ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography,
          a.geog,
          200
        )
        WHERE p.place_type IN ('hotel', 'hostel')
          AND p.agoda_metadata IS NULL
          AND p.latitude IS NOT NULL
          AND p.longitude IS NOT NULL
          AND similarity(LOWER(p.name), LOWER(a.hotel_name)) > 0.6
        ORDER BY p.id, distance_meters ASC, name_similarity DESC
      )
      UPDATE places
      SET agoda_metadata = jsonb_build_object(
        'hotel_id', rm.hotel_id,
        'photo1', rm.photo1,
        'photo2', rm.photo2,
        'photo3', rm.photo3,
        'photo4', rm.photo4,
        'photo5', rm.photo5,
        'overview', rm.overview,
        'matched_by', 'fuzzy_name_200m',
        'distance_meters', rm.distance_meters,
        'name_similarity', rm.name_similarity
      )
      FROM ranked_matches rm
      WHERE places.id = rm.place_id
      RETURNING places.id;
    SQL
    stage2_count = stage2_result.count
    puts "✓ Stage 2 complete: #{stage2_count} places matched"
    puts ""

    # Step 8: Match Stage 3 - Wider proximity search (within 500m, name >70% similar)
    puts "Step 8: Stage 3 - Matching by wider proximity (within 500m, >70% name similarity)..."
    stage3_result = ActiveRecord::Base.connection.execute(<<~SQL)
      WITH ranked_matches AS (
        SELECT DISTINCT ON (p.id)
          p.id as place_id,
          a.hotel_id,
          a.photo1,
          a.photo2,
          a.photo3,
          a.photo4,
          a.photo5,
          a.overview,
          ST_Distance(ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography, a.geog) as distance_meters,
          similarity(LOWER(p.name), LOWER(a.hotel_name)) as name_similarity
        FROM places p
        JOIN agoda_hotels_temp a ON ST_DWithin(
          ST_SetSRID(ST_MakePoint(p.longitude, p.latitude), 4326)::geography,
          a.geog,
          500
        )
        WHERE p.place_type IN ('hotel', 'hostel')
          AND p.agoda_metadata IS NULL
          AND p.latitude IS NOT NULL
          AND p.longitude IS NOT NULL
          AND similarity(LOWER(p.name), LOWER(a.hotel_name)) > 0.7
        ORDER BY p.id, distance_meters ASC, name_similarity DESC
      )
      UPDATE places
      SET agoda_metadata = jsonb_build_object(
        'hotel_id', rm.hotel_id,
        'photo1', rm.photo1,
        'photo2', rm.photo2,
        'photo3', rm.photo3,
        'photo4', rm.photo4,
        'photo5', rm.photo5,
        'overview', rm.overview,
        'matched_by', 'fuzzy_name_500m',
        'distance_meters', rm.distance_meters,
        'name_similarity', rm.name_similarity
      )
      FROM ranked_matches rm
      WHERE places.id = rm.place_id
      RETURNING places.id;
    SQL
    stage3_count = stage3_result.count
    puts "✓ Stage 3 complete: #{stage3_count} places matched"
    puts ""

    # Step 9: Summary
    total_matched = stage1_count + stage2_count + stage3_count
    remaining = places_count - total_matched

    puts "=" * 80
    puts "IMPORT SUMMARY"
    puts "=" * 80
    puts "Total hotels/hostels processed: #{places_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Stage 1 (Proximity 50m):      #{stage1_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Stage 2 (Name + 200m):         #{stage2_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Stage 3 (Name + 500m):         #{stage3_count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  ---"
    puts "  Total matched:                 #{total_matched.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Remaining unmatched:           #{remaining.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  Match rate:                    #{(total_matched * 100.0 / places_count).round(1)}%"
    puts ""
    puts "Completed at: #{Time.current}"
    puts "=" * 80
    puts ""
    puts "💡 Tip: To review unmatched places, run:"
    puts "   Place.where(place_type: ['hotel', 'hostel']).where(\"agoda_metadata IS NULL\").count"
  ensure
    # Cleanup tempfile
    if tempfile
      tempfile.close
      tempfile.unlink
      puts ""
      puts "✓ Temporary file cleaned up"
    end
  end
end

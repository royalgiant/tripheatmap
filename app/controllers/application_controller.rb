class ApplicationController < ActionController::Base
  
  def s3_client
    s3_client ||= Aws::S3::Client.new
  end

  def call_claude_api(prompt, system_prompt)
    client = Anthropic::Client.new

    client.messages(
      parameters: {
        model: "claude-3-haiku-20240307",
        system: system_prompt,
        messages: [
          { role: "user", content: prompt }
        ],
        max_tokens: 4096
      }
    )
  end

  # Get all cities with proper slugs for where-to-stay pages
  def get_cities
    # Get city data with country and continent
    city_data = Neighborhood
      .where.not(city: nil)
      .select('city, country, continent, COUNT(*) as neighborhood_count')
      .group(:city, :country, :continent)
      .order('city ASC')

    city_data.map do |record|
      display_name = CityDataImporter::DISPLAY_NAMES[record.city] || record.city.titleize

      {
        key: record.city,
        name: display_name,
        slug: record.city.gsub('.', '').gsub(' ', '-'),
        neighborhood_count: record.neighborhood_count,
        country: record.country,
        continent: record.continent
      }
    end.sort_by { |city_data| city_data[:name] }
  end

  def get_cities_grouped_by_location(cities_to_group = nil)
    cities = cities_to_group || get_cities
    grouped = cities.group_by do |city| 
      (city.is_a?(Hash) ? city[:continent] : city.try(:continent)) || 'Other'
    end.transform_values do |continent_cities| 
      continent_cities.group_by do |city| 
        (city.is_a?(Hash) ? city[:country] : city.try(:country)) || 'Unknown'
      end 
    end

    continent_order = ['North America', 'Central America', 'Caribbean', 'South America', 'Europe', 'Asia', 'Africa', 'Oceania', 'Other']
    sorted_grouped = continent_order.map { |continent| [continent, grouped[continent]] }.to_h.compact

    sorted_grouped
  end

  private

  def authorize_user!(record)
    unless record&.user == current_user
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to root_path
    end
  end

  def mobile_request?
    request.headers['X-Mobile-App'] == 'true'
  end
end

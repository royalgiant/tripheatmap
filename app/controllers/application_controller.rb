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
    city_counts = Neighborhood
      .where.not(city: nil)
      .group(:city)
      .count

    city_counts.map do |city, neighborhood_count|
      display_name = CityDataImporter::DISPLAY_NAMES[city] || city.titleize

      {
        key: city,
        name: display_name,
        slug: city.gsub('.', '').gsub(' ', '-'),
        neighborhood_count: neighborhood_count
      }
    end.sort_by { |city_data| city_data[:name] }
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

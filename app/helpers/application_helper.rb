module ApplicationHelper
  def is_admin_or_subscribed?
    current_user.present? && (current_user.is_admin? || current_user.subscribed?)
  end

  def google_maps_url(place_or_options = nil, name: nil, lat: nil, lon: nil, zoom: 15)
    if place_or_options.is_a?(Hash)
      name = place_or_options[:name]
      lat = place_or_options[:lat]
      lon = place_or_options[:lon]
      zoom = place_or_options[:zoom] || 15
    elsif place_or_options.respond_to?(:name) && place_or_options.respond_to?(:lat) && place_or_options.respond_to?(:lon)
      name = place_or_options.name
      lat = place_or_options.lat
      lon = place_or_options.lon
    end

    return nil unless name.present? && lat.present? && lon.present?
    encoded_name = ERB::Util.url_encode(name).gsub('%20', '+')
    "https://www.google.com/maps/search/#{encoded_name}/@#{lat},#{lon},#{zoom}z?entry=ttu"
  end

  # Helper to display star ratings with half stars using Tailwind CSS
  def star_rating(rating)
    return unless rating.present?

    # Round to nearest 0.5
    rounded_rating = (rating * 2).round / 2.0
    
    # Calculate full, half, and empty stars
    full_stars = rounded_rating.floor
    half_star = (rounded_rating % 1).positive?
    empty_stars = 5 - full_stars - (half_star ? 1 : 0)

    html = '<div class="flex items-center space-x-0.5 text-yellow-500">'
    
    # Full Stars
    full_stars.times do
      html += <<~HTML
        <svg class="w-4 h-4 fill-current" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
        </svg>
      HTML
    end

    # Half Star
    if half_star
      html += <<~HTML
        <div class="relative w-4 h-4">
          <!-- Background Gray Star -->
          <svg class="w-4 h-4 text-gray-300 fill-current" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
            <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
          </svg>
          <!-- Foreground Yellow Star (Clipped) -->
          <div class="absolute top-0 left-0 h-full overflow-hidden" style="width: 50%;">
            <svg class="w-4 h-4 text-yellow-500 fill-current" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
              <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
            </svg>
          </div>
        </div>
      HTML
    end

    # Empty Stars
    empty_stars.times do
      html += <<~HTML
        <svg class="w-4 h-4 text-gray-300 fill-current" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
        </svg>
      HTML
    end

    html += '</div>'
    html.html_safe
  end
end
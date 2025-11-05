class Api::V1::RedditPostsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def index
    posts = RedditPost.analyzed
      .where.not(lat: nil, lon: nil)
      .select(:id, :city, :neighborhood, :country, :lat, :lon, :risk_level, :risk_score, :incident_type, :summary)
    
    # Group posts by exact coordinates to identify clusters
    coord_groups = posts.group_by { |p| [p.lat.round(4), p.lon.round(4)] }
    
    result = []
    
    coord_groups.each do |coords, posts_at_location|
      lat, lon = coords
      
      # If multiple posts at same location, create individual points with slight offsets
      if posts_at_location.size > 1
        # Group by neighborhood if available
        neighborhood_groups = posts_at_location.group_by { |p| p.neighborhood.present? ? p.neighborhood : nil }
        
        neighborhood_groups.each do |neighborhood, neighborhood_posts|
          if neighborhood.present?
            # Create one aggregated point for this neighborhood
            risk_levels = neighborhood_posts.map(&:risk_level).compact
            overall_risk = if risk_levels.include?('dangerous')
              'dangerous'
            elsif risk_levels.include?('caution')
              'caution'
            else
              'safe'
            end
            
            avg_risk_score = neighborhood_posts.sum(&:risk_score).to_f / neighborhood_posts.size
            
            result << {
              city: neighborhood_posts.first.city,
              neighborhood: neighborhood,
              lat: lat,
              lon: lon,
              risk_level: overall_risk,
              risk_score: avg_risk_score.round(2),
              post_count: neighborhood_posts.size,
              summaries: neighborhood_posts.map(&:summary).compact.take(3)
            }
          else
            # Multiple posts without neighborhood at same coords - spread them out in a circle
            neighborhood_posts.each_with_index do |post, idx|
              # Create circular offset pattern
              angle = (2 * Math::PI * idx) / neighborhood_posts.size
              radius = 0.01 * Math.sqrt(neighborhood_posts.size) # Scale radius with count
              
              offset_lat = lat + (radius * Math.cos(angle))
              offset_lon = lon + (radius * Math.sin(angle))
              
              result << {
                city: post.city,
                neighborhood: post.city, # Use city as fallback
                lat: offset_lat,
                lon: offset_lon,
                risk_level: post.risk_level,
                risk_score: post.risk_score.to_f.round(2),
                post_count: 1,
                summaries: [post.summary].compact
              }
            end
          end
        end
      else
        # Single post at this location
        post = posts_at_location.first
        result << {
          city: post.city,
          neighborhood: post.neighborhood.present? ? post.neighborhood : post.city,
          lat: lat,
          lon: lon,
          risk_level: post.risk_level,
          risk_score: post.risk_score.to_f.round(2),
          post_count: 1,
          summaries: [post.summary].compact
        }
      end
    end
    
    render json: result
  end
end
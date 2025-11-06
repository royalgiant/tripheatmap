class Api::V1::RedditPostsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def index
    posts = RedditPost.analyzed
      .where.not(lat: nil, lon: nil)
      .select(:id, :city, :neighborhood, :country, :lat, :lon, :risk_level, :risk_score, :incident_type, :summary)
    
    features = posts.map do |post|
      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [post.lon, post.lat]
        },
        properties: {
          id: post.id,
          city: post.city,
          neighborhood: post.neighborhood || post.city,
          country: post.country,
          risk_level: post.risk_level,
          risk_score: post.risk_score.to_f,
          incident_type: post.incident_type,
          summary: post.summary
        }
      }
    end
    
    render json: {
      type: "FeatureCollection",
      features: features
    }
  end
end
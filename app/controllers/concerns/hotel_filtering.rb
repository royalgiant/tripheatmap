module HotelFiltering
  extend ActiveSupport::Concern

  included do
    before_action :parse_and_apply_filters, only: [:show]
  end

  private

  def parse_and_apply_filters
    @filter_params = parse_filter_params
  end

  def parse_filter_params
    neighborhood_slugs = Array(params[:neighborhood]).select(&:present?)
    neighborhood_ids = []

    if neighborhood_slugs.any?
      # Get city name from the including controller's context
      city = respond_to?(:city_name) ? city_name.downcase : @city_config&.dig('name')&.downcase

      if city.present?
        neighborhood_ids = Neighborhood
          .where(slug: neighborhood_slugs, city: city)
          .pluck(:id)
      end
    end

    # Handle single price and rating values (radio buttons)
    price_param = params[:price].to_s.strip
    rating_param = params[:rating].to_f

    {
      price: ['$', '$$', '$$$', '$$$$'].include?(price_param) ? price_param : nil,
      rating: rating_param > 0 ? [rating_param] : nil,
      neighborhood_ids: neighborhood_ids,
      neighborhood_slugs: neighborhood_slugs,
      max_price: params[:max_price]&.to_f
    }.compact_blank
  end

  def apply_filters(hotels)
    # Handle both ActiveRecord::Relation and Array
    if hotels.is_a?(Array)
      apply_filters_to_array(hotels)
    else
      apply_filters_to_relation(hotels)
    end
  end

  def apply_filters_to_relation(relation)
    filtered = relation

    if @filter_params[:price].present?
      filtered = filtered.where(price_range: @filter_params[:price])
    end

    if @filter_params[:rating].present?
      min_rating = @filter_params[:rating].is_a?(Array) ? @filter_params[:rating].first : @filter_params[:rating]
      filtered = filtered.where('rating >= ?', min_rating)
    end

    if @filter_params[:neighborhood_ids].present?
      filtered = filtered.where(neighborhood_id: @filter_params[:neighborhood_ids])
    end

    if @filter_params[:max_price].present?
      filtered = filtered.where('average_price <= ? OR average_price IS NULL', @filter_params[:max_price])
    end

    filtered
  end

  def apply_filters_to_array(array)
    filtered = array

    if @filter_params[:price].present?
      filtered = filtered.select { |hotel| hotel.price_range == @filter_params[:price] }
    end

    if @filter_params[:rating].present?
      min_rating = @filter_params[:rating].is_a?(Array) ? @filter_params[:rating].first : @filter_params[:rating]
      filtered = filtered.select { |hotel| hotel.rating && hotel.rating >= min_rating }
    end

    if @filter_params[:neighborhood_ids].present?
      filtered = filtered.select { |hotel| @filter_params[:neighborhood_ids].include?(hotel.neighborhood_id) }
    end

    if @filter_params[:max_price].present?
      filtered = filtered.select { |hotel| hotel.average_price.nil? || hotel.average_price <= @filter_params[:max_price] }
    end

    filtered
  end

  def generate_seo_metadata(base_title:, base_description:, fallback_title:, fallback_description:)
    title_parts = []
    description_parts = []

    # Add price filter to SEO
    if @filter_params[:price].present?
      price_labels = { '$' => 'budget', '$$' => 'affordable', '$$$' => 'upscale', '$$$$' => 'luxury' }
      price_term = price_labels[@filter_params[:price]]
      if price_term
        title_parts << price_term
        description_parts << "#{price_term} options"
      end
    end

    # Add rating filter to SEO
    if @filter_params[:rating].present?
      min_rating = @filter_params[:rating].is_a?(Array) ? @filter_params[:rating].first : @filter_params[:rating]
      title_parts << "#{min_rating}+ rated"
      description_parts << "highly-rated (#{min_rating}+ stars)"
    end

    # Add neighborhood filter to SEO
    if @filter_params[:neighborhood_slugs].present?
      city = respond_to?(:city_name) ? city_name.downcase : @city_config&.dig('name')&.downcase

      if city.present?
        neighborhoods = Neighborhood
          .where(slug: @filter_params[:neighborhood_slugs], city: city)
          .pluck(:name)

        if neighborhoods.any?
          neighborhood_str = neighborhoods.join(', ')
          title_parts << "in #{neighborhood_str}"
          description_parts << "located in #{neighborhood_str}"
        end
      end
    end

    # Add max price filter to SEO
    if @filter_params[:max_price].present?
      title_parts << "under $#{@filter_params[:max_price].to_i}"
      description_parts << "priced under $#{@filter_params[:max_price].to_i}/night"
    end

    # Build final title and description
    if title_parts.any?
      title = "#{base_title} - #{title_parts.join(', ').capitalize} (#{Time.current.year})"
      description = "#{base_description} - #{description_parts.join(', ')}."
    else
      title = fallback_title
      description = fallback_description
    end

    { title: title, description: description }
  end

  def canonical_url_with_filters(base_url_method, *args)
    send(base_url_method, *args, @filter_params.presence)
  end
end

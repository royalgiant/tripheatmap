module ContinentHelper
  # Determine continent from country name
  def determine_continent(country)
    case country
    when "United Kingdom", "Ireland", "Italy"
      "Europe"
    when "Canada", "United States"
      "North America"
    when "Australia", "New Zealand"
      "Oceania"
    when "Singapore", "Hong Kong SAR", "United Arab Emirates"
      "Asia"
    when "Argentina"
      "South America"
    else
      nil
    end
  end
end

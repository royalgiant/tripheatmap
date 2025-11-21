module ContinentHelper
  # Determine continent from country name
  def determine_continent(country)
    case country
    when "United Kingdom", "Ireland", "Italy", "Germany", "Netherlands", "Switzerland",
         "Sweden", "Denmark", "Belgium", "France", "Austria", "Norway", "Spain",
         "Portugal", "Greece"
      "Europe"
    when "Canada", "United States", "Mexico"
      "North America"
    when "Australia", "New Zealand"
      "Oceania"
    when "Singapore", "Hong Kong SAR", "United Arab Emirates", "Japan", "Thailand", "Vietnam"
      "Asia"
    when "Argentina", "Brazil"
      "South America"
    else
      nil
    end
  end
end

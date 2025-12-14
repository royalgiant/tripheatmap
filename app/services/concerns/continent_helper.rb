module ContinentHelper
  # Determine continent from country name
  def determine_continent(country)
    case country
    when "United Kingdom", "Ireland", "Italy", "Germany", "Netherlands", "Switzerland",
         "Sweden", "Denmark", "Belgium", "France", "Austria", "Norway", "Spain",
         "Portugal", "Greece", "Czech Republic", "Hungary", "Iceland", "Poland", "Russia"
      "Europe"
    when "Canada", "United States", "Mexico"
      "North America"
    when "Costa Rica", "Panama"
      "Central America"
    when "Bahamas", "Dominican Republic"
      "Caribbean"
    when "Australia", "New Zealand"
      "Oceania"
    when "Singapore", "Hong Kong SAR", "United Arab Emirates", "Japan", "Thailand", "Vietnam",
         "China", "India", "Indonesia", "Israel", "Malaysia", "Philippines", "Qatar",
         "Saudi Arabia", "South Korea", "Taiwan", "Turkey"
      "Asia"
    when "Argentina", "Brazil", "Colombia", "Peru"
      "South America"
    when "Egypt", "Morocco", "South Africa"
      "Africa"
    else
      nil
    end
  end
end

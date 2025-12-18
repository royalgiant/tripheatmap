Geocoder.configure(
  # IP address geocoding service (use ipapi.co for free IP geolocation)
  ip_lookup: :ipapi_com,

  # Geocoding timeout (in seconds)
  timeout: 3,

  # Use HTTPS
  use_https: true,

  # Units
  units: :mi,  # :km for kilometers
)

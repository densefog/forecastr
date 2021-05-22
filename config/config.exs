use Mix.Config

config :forecastr,
  appid: System.get_env("FORECASTR_API_KEY"),
  backend: Forecastr.OWM,
  giphy_api_key: System.get_env("GIPHY_API_KEY"),
  # 10 minutes of caching time to live
  ttl: 10 * 60_000,
  latitude: System.get_env("LATITUDE"),
  longitude: System.get_env("LONGITUDE")

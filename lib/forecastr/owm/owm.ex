defmodule Forecastr.OWM do
  @moduledoc false

  @type when_to_forecast :: :today | :next_days | :hourly
  @spec weather(when_to_forecast, String.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, atom()}
  def weather(when_to_forecast, query, latitude \\ "", longitude \\ "", opts) do
    endpoint = owm_api_endpoint(when_to_forecast, query, latitude, longitude)

    fetch_weather_information(endpoint, opts)
  end

  @doc """
  Normalize for today's weather, next 5 days weather, or hourly weather
  """
  @spec normalize(map()) :: {:ok, map()}
  def normalize(%{
        "name" => name,
        "sys" => %{"country" => country},
        "coord" => %{"lat" => lat, "lon" => lon},
        "weather" => weather,
        "main" => %{"temp" => temp, "temp_max" => temp_max, "temp_min" => temp_min}
      }) do
    normalized =
      weather
      |> extract_main_weather()
      |> add("name", name)
      |> add("country", country)
      |> add("coordinates", %{"lat" => lat, "lon" => lon})
      |> add("temp", temp)
      |> add("temp_max", temp_max)
      |> add("temp_min", temp_min)

    {:ok, normalized}
  end

  def normalize(%{
        "city" => %{
          "name" => name,
          "country" => country,
          "coord" => %{"lat" => lat, "lon" => lon}
        },
        "list" => forecast_list
      })
      when is_list(forecast_list) do
    normalized =
      Map.new()
      |> add("name", name)
      |> add("country", country)
      |> add("coordinates", %{"lat" => lat, "lon" => lon})
      |> add("list", forecast_list |> Enum.map(&normalize_forecast_list/1))

    {:ok, normalized}
  end

  # For Hourly
  def normalize(%{
        "hourly" => hourly,
        "lat" => lat,
        "lon" => lon
      })
      when is_list(hourly) do
    normalized =
      Map.new()
      |> add("coordinates", %{"lat" => lat, "lon" => lon})
      |> add("hourly", hourly |> Enum.map(&normalize_hourly_list/1))

    {:ok, normalized}
  end

  defp fetch_weather_information(endpoint, opts) do
    case Forecastr.OWM.HTTP.get(endpoint, [], params: opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :api_key_invalid}

      {:error, _reason} = error ->
        error
    end
  end

  defp extract_main_weather(weather) do
    %{"description" => main_weather_condition, "id" => weather_id} = List.first(weather)
    %{"description" => main_weather_condition, "id" => weather_id}
  end

  defp normalize_forecast_list(%{
         "weather" => weather,
         "main" => %{
           "temp" => temp,
           "temp_max" => temp_max,
           "temp_min" => temp_min
         },
         "dt_txt" => dt_txt,
         "dt" => dt
       }) do
    weather
    |> extract_main_weather()
    |> add("temp", temp)
    |> add("temp_max", temp_max)
    |> add("temp_min", temp_min)
    |> add("dt_txt", dt_txt)
    |> add("dt", dt)
  end

  defp normalize_hourly_list(
         %{
           "dt" => dt,
           "pop" => prob_of_precipitation,
           "temp" => temp,
           "wind_speed" => wind_speed
         } = hour
       ) do
    rain = get_in(hour, ["rain", "1h"])

    %{
      "dt" => dt,
      "pop" => prob_of_precipitation,
      "temp" => temp,
      "wind_speed" => wind_speed,
      "rain" => rain || 0
    }
  end

  defp add(map, key, value) do
    map
    |> Map.put(key, value)
  end

  @spec owm_api_endpoint(when_to_forecast, String.t(), String.t(), String.t()) :: String.t()
  def owm_api_endpoint(:today, query, _latitude, _longitude),
    do: "api.openweathermap.org/data/2.5/weather?q=#{query}"

  def owm_api_endpoint(:next_days, query, _latitude, _longitude),
    do: "api.openweathermap.org/data/2.5/forecast?q=#{query}"

  # Does not have query parameter, uses lat lon
  def owm_api_endpoint(:hourly, _query, latitude, longitude),
    do:
      "api.openweathermap.org/data/2.5/onecall?exclude=minutely,current,daily,alerts&lat=#{
        latitude
      }&lon=#{longitude}"
end

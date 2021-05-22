defmodule Forecastr.Darksky do
  @moduledoc false

  @type when_to_forecast :: :today | :next_days | :hourly
  @spec weather(when_to_forecast, String.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, atom()}
  def weather(when_to_forecast, query, _latitude, _longitude, opts) do
    endpoint = darksky_api_endpoint(when_to_forecast)
    params = convert_to_darksky_params(opts)

    %{
      "lat" => lat,
      "lon" => lon,
      "address" => %{
        "city" => city,
        "country" => country
      }
    } =
      query
      |> Forecastr.Darksky.Geocoder.geocode()
      |> Enum.at(0, %{})
      |> pick_location()

    with {:ok, forecast} <- fetch_weather_information(endpoint <> "/#{lat},#{lon}", params) do
      {:ok,
       forecast
       |> add("name", city)
       |> add("country", country)
       |> add("when_to_forecast", Atom.to_string(when_to_forecast))}
    end
  end

  @spec normalize(map()) :: {:ok, map()}
  @doc """
  Normalize for today's weather or for the next 3 days weather
  """
  def normalize(%{
        "when_to_forecast" => "today",
        "name" => name,
        "country" => country,
        "latitude" => lat,
        "longitude" => lon,
        "currently" => %{"temperature" => temp = temp_max = temp_min} = weather
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
        "when_to_forecast" => "next_days",
        "name" => name,
        "country" => country,
        "latitude" => lat,
        "longitude" => lon,
        "hourly" => %{"data" => forecast_list}
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

  defp fetch_weather_information(endpoint, opts) do
    case HTTPoison.get(endpoint, [], params: opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: 404}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 400}} ->
        {:error, :not_found}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :api_key_invalid}

      error = {:error, _reason} ->
        error
    end
  end

  defp extract_main_weather(weather) do
    %{"summary" => main_weather_condition, "icon" => icon_name} = weather
    %{"description" => main_weather_condition, "id" => icon_name}
  end

  defp normalize_forecast_list(%{
         "summary" => main_weather_condition,
         "icon" => icon,
         "temperature" => temp = temp_max = temp_min,
         "time" => time
       }) do
    date = time |> DateTime.from_unix!() |> DateTime.to_date() |> to_string()
    time = time |> DateTime.from_unix!() |> DateTime.to_time() |> to_string()

    Map.new()
    |> add("temp", temp)
    |> add("temp_max", temp_max)
    |> add("temp_min", temp_min)
    |> add("dt_txt", "#{date} #{time}")
    |> add("dt", time)
    |> add("description", main_weather_condition)
    |> add("id", icon)
  end

  defp add(map, key, value) do
    map
    |> Map.put(key, value)
  end

  @spec darksky_api_endpoint(when_to_forecast) :: String.t()
  def darksky_api_endpoint(:today),
    do: "https://api.darksky.net/forecast/#{Application.get_env(:forecastr, :appid)}"

  def darksky_api_endpoint(:next_days),
    do: "https://api.darksky.net/forecast/#{Application.get_env(:forecastr, :appid)}"

  def darksky_api_endpoint(:hourly),
    do: raise("Hourly not implemented for DarkSky")

  defp convert_to_darksky_params(%{units: :imperial} = params), do: Map.put(params, :units, "us")
  defp convert_to_darksky_params(%{units: _} = params), do: Map.put(params, :units, "si")
  defp convert_to_darksky_params(%{} = params), do: params

  defp pick_location(%{"address" => %{"city" => _city}} = body), do: body

  defp pick_location(%{"address" => %{"town" => town}} = body),
    do: put_in(body, ["address", "city"], town)

  defp pick_location(%{"address" => %{"village" => village}} = body),
    do: put_in(body, ["address", "city"], village)

  defp pick_location(%{"address" => %{"province" => province}} = body),
    do: put_in(body, ["address", "city"], province)

  defp pick_location(%{"address" => %{"suburb" => suburb}} = body),
    do: put_in(body, ["address", "city"], suburb)
end

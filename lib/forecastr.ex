defmodule Forecastr do
  @moduledoc """
  Forecastr is an application that queries the Open Weather Map API

  The Forecastr user API is exposed in this way:

  # Query the backend weather API for today's weather
  Forecastr.forecast(:today, query, params \\ %{}, renderer \\ Forecastr.Renderer.ASCII )

  # Query the backend weather API for the forecast in the next days
  Forecastr.forecast(:next_days, query, params \\ %{}, renderer \\ Forecastr.Renderer.ASCII )

  For example:

  Forecastr.forecast(:today, "Berlin")

  Forecastr.forecast(:next_days, "Berlin", %{units: :imperial})

  Forecastr.forecast(:today, "Lima", %{units: :imperial}, Forecastr.Renderer.PNG)
  """

  @type renderer ::
          Forecastr.Renderer.ASCII
          | Forecastr.Renderer.ANSI
          | Forecastr.Renderer.HTML
          | Forecastr.Renderer.JSON
          | Forecastr.Renderer.PNG
  @type when_to_forecast :: :today | :next_days
  @spec forecast(
          when_to_forecast,
          query :: String.t(),
          latitude :: String.t(),
          longitude :: String.t(),
          params :: map(),
          renderer
        ) ::
          {:ok, binary()} | {:ok, list(binary())} | {:error, atom()}
  def forecast(
        when_to_forecast,
        query,
        latitude,
        longitude,
        params \\ %{units: :metric},
        renderer \\ Forecastr.Renderer.ASCII
      )

  def forecast(when_to_forecast, query, latitude, longitude, params, renderer)
      when is_binary(query) do
    location = String.downcase(query)
    forecast(when_to_forecast, location, latitude, longitude, params, renderer)
  end

  def forecast(when_to_forecast, location, latitude, longitude, params, renderer) do
    with {:ok, response} <- perform_query(location, latitude, longitude, when_to_forecast, params) do
      {:ok, renderer.render(response)}
    end
  end

  defp perform_query(query, latitude, longitude, when_to_forecast, params) do
    with {:ok, :miss} <- fetch_from_cache(when_to_forecast, query, latitude, longitude),
         {:ok, response} <-
           fetch_from_backend(when_to_forecast, query, latitude, longitude, params),
         :ok <- Forecastr.Cache.set(when_to_forecast, query, latitude, longitude, response) do
      {:ok, response}
    else
      {:ok, _response} = response -> response
      {:error, _} = error -> error
    end
  end

  defp fetch_from_cache(when_to_forecast, query, latitude, longitude) do
    case Forecastr.Cache.get(when_to_forecast, query, latitude, longitude) do
      nil -> {:ok, :miss}
      response -> {:ok, response}
    end
  end

  defp fetch_from_backend(when_to_forecast, query, latitude, longitude, params) do
    backend = Application.get_env(:forecastr, :backend)

    with {:ok, weather} <-
           backend.weather(when_to_forecast, query, latitude, longitude, params),
         {:ok, normalized_weather} <- backend.normalize(weather) do
      {:ok, normalized_weather}
    end
  end
end

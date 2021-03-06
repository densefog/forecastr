defmodule Forecastr.Cache do
  @moduledoc """
  "Proxy" module for different caches
  """

  @spec get(:today, String.t(), String.t(), String.t()) :: map() | nil
  def get(:today, query, _latitude, _longitude) do
    Forecastr.Cache.Worker.get(Forecastr.Cache.Today, query)
  end

  @spec get(:next_days, String.t(), String.t(), String.t()) :: map() | nil
  def get(:next_days, query, _latitude, _longitude) do
    Forecastr.Cache.Worker.get(Forecastr.Cache.NextDays, query)
  end

  @spec get(:hourly, String.t(), String.t(), String.t()) :: map() | nil
  def get(:hourly, query, latitude, longitude) do
    Forecastr.Cache.Worker.get(Forecastr.Cache.Hourly, query, latitude, longitude)
  end

  @spec set(:today, String.t(), String.t(), String.t(), map()) :: :ok
  def set(:today, query, _latitude, _longitude, response) do
    Forecastr.Cache.Worker.set(Forecastr.Cache.Today, query, response)
  end

  @spec set(:next_days, String.t(), String.t(), String.t(), map()) :: :ok
  def set(:next_days, query, _latitude, _longitude, response) do
    Forecastr.Cache.Worker.set(Forecastr.Cache.NextDays, query, response)
  end

  @spec set(:hourly, String.t(), String.t(), String.t(), map()) :: :ok
  def set(:hourly, query, latitude, longitude, response) do
    Forecastr.Cache.Worker.set(Forecastr.Cache.Hourly, query, latitude, longitude, response)
  end
end

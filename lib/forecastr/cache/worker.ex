defmodule Forecastr.Cache.Worker do
  @moduledoc false

  use GenServer

  # Client API
  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link([name: worker_name] = opts) do
    GenServer.start_link(__MODULE__, %{name: worker_name}, opts)
  end

  @spec get(atom(), String.t(), String.t(), String.t()) :: map() | nil
  def get(name, query, latitude \\ "", longitude \\ "") do
    GenServer.call(name, {:get, "#{query}::#{latitude}::#{longitude}"})
  end

  @spec set(atom(), String.t(), String.t(), String.t(), map()) :: :ok
  def set(name, query, latitude \\ "", longitude \\ "", response) do
    expiration_minutes = Application.get_env(:forecastr, :ttl, 10 * 60_000)

    GenServer.call(
      name,
      {:set, "#{query}::#{latitude}::#{longitude}", response, ttl: expiration_minutes}
    )
  end

  # Server callbacks
  def init(%{name: worker_name} = state) do
    ^worker_name = :ets.new(worker_name, [:named_table])
    {:ok, state}
  end

  def handle_call({:get, query}, _from, %{name: worker_name} = state) do
    entry =
      case :ets.lookup(worker_name, query) do
        [] -> nil
        [{_key, value}] -> value
      end

    {:reply, entry, state}
  end

  def handle_call(
        {:set, query, response, options},
        _from,
        %{name: worker_name} = state
      ) do
    true = :ets.insert(worker_name, {query, response})
    schedule_purge_cache(query, options)
    {:reply, :ok, state}
  end

  def schedule_purge_cache(query, ttl: minutes) do
    Process.send_after(self(), {:purge_cache, query}, minutes)
  end

  def handle_info({:purge_cache, query}, %{name: worker_name} = state) do
    true = :ets.delete(worker_name, query)
    {:noreply, state}
  end
end

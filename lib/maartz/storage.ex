defmodule Maartz.Storage do
  @moduledoc """
  A small helper module for interacting with an ETS table
  """

  @table_name :walked_urls

  def create_table, do: :ets.new(@table_name, [:set, :public, :named_table])

  def put(url) do
    key = generate_key(url)
    :ets.insert(@table_name, {key, url})
  end

  def exists?(url) do
    key = generate_key(url)

    case :ets.lookup(@table_name, key) do
      [{^key, _url}] -> true
      _no_match -> false
    end
  end

  defp generate_key(url) do
    url
    |> URI.parse()
    |> Map.merge(%{fragment: nil, query: nil})
    |> URI.to_string()
    |> Base.encode64()
  end
end

defmodule Maartz do
  @moduledoc """
  Documentation for `Maartz`.
  """

  alias Maartz.Storage

  @url "https://www.carrefour.fr"

  def run, do: walk(@url)

  defp get_tag(content, selector) do
    with [{_, _, [content]}] <- Floki.find(content, selector) do
      String.trim(content)
    else
      _not_found -> nil
    end
  end

  defp internal_links(document) do
    document
    |> Floki.find("a")
    |> Enum.reduce([], &internal_link_reducer/2)
    |> Enum.reject(&Storage.exists?/1)
  end

  defp internal_link_reducer({_tag_name, attributes, _children}, acc) do
    links =
      Enum.flat_map(attributes, fn
        {"href", "/" <> _internal_path = path} -> [@url <> path]
        _no_match -> []
      end)

    links ++ acc
  end

  defp product_information(document) do
    with title when not is_nil(title) <- get_tag(document, "h1.pdp-card__title"),
         price when not is_nil(price) <- get_tag(document, ".product-card-price__price--final") do
      IO.puts("#{title} - #{price}")
    end
  end

  defp walk(url) do
    task =
      Task.Supervisor.async(Maartz.TaskSupervisor, fn ->
        with true <- Storage.put(url),
             {:ok, %{body: body}} <- HTTPoison.get(url),
             {:ok, document} <- Floki.parse_document(body) do
          product_information(document)
          walk_internal_links(document)
        end
      end)

    Task.await(task, :infinity)
  end

  defp walk_internal_links(document) do
    document
    |> internal_links()
    |> Enum.each(&walk/1)
  end
end

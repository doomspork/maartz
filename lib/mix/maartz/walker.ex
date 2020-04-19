defmodule Mix.Tasks.Maartz.Walker do
  @moduledoc """
  Run our site crawler as a Mix task
  """
  use Mix.Task

  @shortdoc "Walk carrefour.fr for products and prices"
  def run(_opts) do
    Application.ensure_all_started(:maartz)
    Maartz.run()
  end
end

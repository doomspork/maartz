defmodule Maartz do
  @moduledoc """
  Documentation for `Maartz`.
  """

  alias Maartz.Storage

  @url "https://beansbooks.com/api/action/Beans_Account_Calibrate"

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
        {"href", "/api/object" <> _internal_path} -> []
        {"href", "/api/" <> internal_path} -> [@url <> internal_path]
        _no_match -> []
      end)

    links ++ acc
  end

  defp parse_description({_tag, _attrs, child_nodes}) do
    nodes =
      case List.last(child_nodes) do
        {"table", [], []} ->
          {_, new_nodes} = List.pop_at(child_nodes, -1)
          new_nodes

        other ->
          other
      end

    case nodes do
      [{_, [{"class", "type"}], [type]}] ->
        {type, "", []}

      [{_, [{"class", "type"}], [type]}, desc] ->
        {type, String.trim(desc), []}

      [
        {_, [{"class", "type"}], [type]},
        start,
        {"a", _attrs, [resource]},
        ending
      ] ->
        {type, String.trim("#{start}#{resource}#{ending}"), []}

      [{_, [{"class", "type"}], [type]}, title, nested_nodes] ->
        nodes = Floki.find(nested_nodes, "tr")
        {type, String.trim(title), build_table(nodes, "  *")}

      [desc] ->
        {"", desc, []}
    end
  end

  defp parse_row({_tag, _attrs, [name, description]}, prefix) do
    {requirement, field} =
      case name do
        {_, [{_, field_requirement}], [field]} -> {field_requirement, field}
        {_, _, [field]} -> {"", field}
      end

    required = if requirement == "", do: "", else: " (#{requirement})"
    {type, desc, nested_params} = parse_description(description)

    "#{prefix} #{field}#{required} #{type} - #{String.trim(desc)}\n#{nested_params}"
  end

  defp build_table(content, prefix \\ "*") do
    content
    |> Enum.map(&parse_row(&1, prefix))
    |> Enum.join("\n")
  end

  defp parse_parameters(document) do
    case Floki.find(document, "h3 + table") do
      [{_, _, parameters}, {_, _, results}] ->
        {build_table(Floki.find(parameters, "tr")), build_table(Floki.find(results, "tr"))}

      [{_, _, parameters}] ->
        {build_table(Floki.find(parameters, "tr")), nil}

      _other ->
        [{_, _, parameters}] = Floki.find(document, "table")
        {build_table(Floki.find(parameters, "tr")), nil}
    end
  end

  defp markdown_doc(title, description, parameters, nil) do
    """
    # #{title}
    #{description}
    ***
    ## Attributes
    #{parameters}
    """
  end

  defp markdown_doc(title, description, parameters, results) do
    """
    # #{title}
    #{description}
    ***
    ## Parameters
    #{parameters}
    *** 
    ## Results
    #{results}
    """
  end

  defp api_doc(document) do
    with title <- get_tag(document, "h2"),
         description <- get_tag(document, "p.lead"),
         {parameters, results} <- parse_parameters(document) do
      filename = String.downcase("docs/#{title}.md")
      markdown = markdown_doc(title, description, parameters, results)
      File.write(filename, markdown)
    else
      err -> IO.inspect(err, label: :error)
    end
  end

  defp walk(url) do
    task =
      Task.Supervisor.async(Maartz.TaskSupervisor, fn ->
        with true <- Storage.put(url),
             {:ok, %{body: body}} <- HTTPoison.get(url),
             {:ok, document} <- Floki.parse_document(body) do
          IO.inspect(url)

          api_doc(document)
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

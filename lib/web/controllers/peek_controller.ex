defmodule Accent.PeekController do
  use Phoenix.Controller

  import Canary.Plugs

  alias Accent.Project
  alias Movement.Builders.ProjectSync, as: ProjectSyncBuilder
  alias Movement.Builders.RevisionMerge, as: RevisionMergeBuilder
  alias Movement.Context

  plug(Plug.Assign, [canary_action: :peek_merge] when action === :merge)
  plug(Plug.Assign, [canary_action: :peek_sync] when action === :sync)
  plug(:load_and_authorize_resource, model: Project, id_name: "project_id")
  plug(Accent.Plugs.AssignRevisionLanguage when action === :merge)
  plug(Accent.Plugs.MovementContextParser)
  plug(:assign_merge_comparer when action in [:merge])
  plug(:assign_merge_options when action in [:merge])
  plug(:assign_sync_comparer when action in [:sync])

  @doc """
  Peek operations that would be created when doing a sync

  ## Endpoint

    GET /sync/peek

  ### Required params
    - `project_id`
    - `language_id`
    - `file`
    - `document_path`
    - `document_format`

  ### Optional params
    - `merge_type`

  ### Response

    #### Success
    `200` - List of serialized operations grouped in master_operations and slaves_operations keys

    #### Error
    `404` - Unknown project
  """
  def sync(conn, _params) do
    operations =
      conn.assigns[:movement_context]
      |> Context.assign(:project, conn.assigns[:project])
      |> ProjectSyncBuilder.build()
      |> Map.get(:operations)
      |> Enum.group_by(&Map.get(&1, :revision_id))

    render(conn, "index.json", operations: operations)
  end

  @doc """
  Peek operations that would be created when doing a merge

  ## Endpoint

    GET /merge/peek

  ### Required params
    - `project_id`
    - `language_id`
    - `file`
    - `document_path`
    - `document_format`

  ### Optional params
    - `merge_type`
    - `sync_type`

  ### Response

    #### Success
    `200` - List of serialized operations

    #### Error
    `404` - Unknown revision
    `422` - Invalid file
  """
  def merge(conn, _params) do
    operations =
      conn.assigns[:movement_context]
      |> Context.assign(:revision, conn.assigns[:revision])
      |> Context.assign(:options, conn.assigns[:merge_options])
      |> RevisionMergeBuilder.build()
      |> Map.get(:operations)
      |> Enum.group_by(&Map.get(&1, :revision_id))

    render(conn, "index.json", operations: operations)
  end

  defp assign_sync_comparer(conn, _) do
    comparer = Movement.Comparer.comparer(:sync, conn.params["sync_type"])
    context = Context.assign(conn.assigns[:movement_context], :comparer, comparer)

    assign(conn, :movement_context, context)
  end

  defp assign_merge_comparer(conn, _) do
    comparer = Movement.Comparer.comparer(:merge, conn.params["merge_type"])
    context = Context.assign(conn.assigns[:movement_context], :comparer, comparer)

    assign(conn, :movement_context, context)
  end

  defp assign_merge_options(conn, _) do
    case conn.params["merge_options"] do
      options when is_binary(options) -> assign(conn, :merge_options, String.split(options, ","))
      _ -> assign(conn, :merge_options, [])
    end
  end
end

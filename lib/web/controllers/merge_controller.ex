defmodule Accent.MergeController do
  use Plug.Builder

  import Canary.Plugs

  alias Movement.Builders.RevisionMerge, as: RevisionMergeBuilder
  alias Movement.Persisters.RevisionMerge, as: RevisionMergePersister

  alias Accent.Hook.Context, as: HookContext
  alias Accent.Project

  plug(Plug.Assign, canary_action: :merge)
  plug(:load_and_authorize_resource, model: Project, id_name: "project_id")
  plug(Accent.Plugs.EnsureUnlockedFileOperations)
  plug(Accent.Plugs.AssignRevisionLanguage)
  plug(Accent.Plugs.MovementContextParser)
  plug(:assign_comparer)
  plug(:assign_merge_options)
  plug(:create)

  @doc """
  Create new merge for a project and a language

  ## Endpoint

    GET /add-translations

  ### Required params
    - `project_id`
    - `language_id`
    - `file`

  ### Optional params
    - `merge_type` (smart, force or passive), default: smart.
    - `merge_options`

  ### Response

    #### Success
    `200` - Ok.

    #### Error
    `404` - Unknown revision
    `422` - Invalid file
  """
  def create(conn, _params) do
    conn.assigns[:movement_context]
    |> Movement.Context.assign(:revision, conn.assigns[:revision])
    |> Movement.Context.assign(:merge_type, conn.assigns[:merge_type])
    |> Movement.Context.assign(:options, conn.assigns[:merge_options])
    |> Movement.Context.assign(:user_id, conn.assigns[:current_user].id)
    |> RevisionMergeBuilder.build()
    |> RevisionMergePersister.persist()
    |> case do
      {:ok, {_context, []}} ->
        send_resp(conn, :ok, "")

      {:ok, _} ->
        Accent.Hook.outbound(%HookContext{
          event: "merge",
          project_id: conn.assigns[:project].id,
          user_id: conn.assigns[:current_user].id,
          payload: %{
            merge_type: conn.assigns[:merge_type],
            language_name: conn.assigns[:revision].language.name
          }
        })

        send_resp(conn, :ok, "")

      {:error, _reason} ->
        send_resp(conn, :unprocessable_entity, "")
    end
  end

  defp assign_comparer(conn, _) do
    comparer = Movement.Comparer.comparer(:merge, conn.params["merge_type"])
    context = Movement.Context.assign(conn.assigns[:movement_context], :comparer, comparer)

    assign(conn, :movement_context, context)
  end

  defp assign_merge_options(conn, _) do
    case conn.params["merge_options"] do
      options when is_binary(options) ->
        options = Enum.reject(String.split(options, ","), &(&1 in ["", nil]))
        assign(conn, :merge_options, options)

      _ ->
        assign(conn, :merge_options, [])
    end
  end
end

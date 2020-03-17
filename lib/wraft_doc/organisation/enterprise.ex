defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto.Query
  import Ecto

  alias WraftDoc.{
    Repo,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Enterprise.Organisation,
    Account.User
  }

  @doc """
  Get a flow from its UUID.
  """
  @spec get_flow(binary) :: Flow.t() | nil
  def get_flow(flow_uuid) do
    Repo.get_by(Flow, uuid: flow_uuid)
  end

  @doc """
  Get a state from its UUID.
  """
  @spec get_state(binary) :: State.t() | nil
  def get_state(state_uuid) do
    Repo.get_by(State, uuid: state_uuid)
  end

  @doc """
  Create a flow.
  """
  @spec create_flow(User.t(), map) ::
          %Flow{creator: User.t()} | {:error, Ecto.Changeset.t()}
  def create_flow(%{organisation_id: org_id} = current_user, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})

    current_user
    |> build_assoc(:flows)
    |> Flow.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, flow} ->
        flow |> Repo.preload(:creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  List of all flows.
  """
  @spec flow_index(User.t(), map) :: map
  def flow_index(%User{organisation_id: org_id}, params) do
    from(f in Flow,
      where: f.organisation_id == ^org_id,
      order_by: [desc: f.id],
      preload: [:creator]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Show a flow.
  """
  @spec show_flow(binary) :: Flow.t() | nil
  def show_flow(flow_uuid) do
    flow_uuid |> get_flow |> Repo.preload([:creator, :states])
  end

  @doc """
  Update a flow.
  """
  @spec update_flow(Flow.t(), map) :: Flow.t() | {:error, Ecto.Changeset.t()}
  def update_flow(flow, params) do
    flow
    |> Flow.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, flow} ->
        flow |> Repo.preload(:creator)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a flow.
  """
  @spec delete_flow(Flow.t()) :: {:ok, Flow.t()} | {:error, Ecto.Changeset.t()}
  def delete_flow(flow) do
    flow
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :states,
      message:
        "Cannot delete the flow. Some States depend on this flow. Delete those states and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Create a state under a flow.
  """
  @spec create_state(User.t(), Flow.t(), map) :: {:ok, State.t()} | {:error, Ecto.Changeset.t()}
  def create_state(%User{organisation_id: org_id} = current_user, flow, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})
    current_user |> build_assoc(:states, flow: flow) |> State.changeset(params) |> Repo.insert()
  end

  @doc """
  State index under a flow.
  """
  @spec state_index(binary, map) :: map
  def state_index(flow_uuid, params) do
    from(s in State,
      join: f in Flow,
      where: f.uuid == ^flow_uuid and s.flow_id == f.id,
      order_by: [desc: s.id],
      preload: [:flow, :creator]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Update a state.
  """
  @spec update_state(State.t(), map) ::
          %State{creator: User.t(), flow: Flow.t()} | {:error, Ecto.Changeset.t()}
  def update_state(state, params) do
    state
    |> State.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, state} ->
        state |> Repo.preload([:creator, :flow])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Shuffle the order of flows.
  """
  @spec shuffle_order(State.t(), integer) :: list
  def shuffle_order(%{order: order, organisation_id: org_id}, additive) do
    from(f in Flow, where: f.organisation_id == ^org_id and f.order > ^order)
    |> Repo.all()
    |> Task.async_stream(fn x -> update_state_order(x, additive) end)
    |> Enum.to_list()
  end

  # Update the flow order by adding the additive.
  @spec update_state_order(State.t(), integer) :: {:ok, State.t()}
  defp update_state_order(%{order: order} = flow, additive) do
    flow
    |> State.order_update_changeset(%{order: order + additive})
    |> Repo.update()
  end

  @doc """
  Delete a state.
  """
  @spec delete_state(State.t()) :: {:ok, State.t()} | {:error, Ecto.Changeset.t()}
  def delete_state(state) do
    state
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the state. Some contents depend on this state. Update those states and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Get an organisation from its UUID.
  """
  @spec get_organisation(binary) :: Organisation.t() | nil
  def get_organisation(org_uuid) do
    Repo.get_by(Organisation, uuid: org_uuid)
  end

  @doc """
  Create an Organisation
  """
  @spec create_organisation(User.t(), map) :: {:ok, Organisation.t()}
  def create_organisation(%User{} = user, params) do
    user
    |> build_assoc(:organisation)
    |> Organisation.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, organisation} ->
        {:ok, organisation}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Update an Organisation
  """
  require IEx
  @spec update_organisation(Organisation.t(), map) :: {:ok, Organisation.t()}
  def update_organisation(%Organisation{} = organisation, params) do
    organisation
    |> Organisation.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, %Organisation{} = organisation} ->
        {:ok, organisation}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes the organisation
  """
  def delete_organisation(%Organisation{} = organisation) do
    organisation
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :users,
      message:
        "Cannot delete the organisation. Some user depend on this organisation. Update those users and then try again.!"
    )
    |> Repo.delete()
  end
end

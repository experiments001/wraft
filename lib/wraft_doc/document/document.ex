defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.{
    Repo,
    Account.User,
    Document.Layout,
    Document.ContentType,
    Document.Engine,
    Document.Instance,
    Document.Instance.History,
    Document.Instance.Version,
    Document.Theme,
    Document.DataTemplate,
    Document.Asset,
    Document.LayoutAsset,
    Document.FieldType,
    Document.ContentTypeField,
    Document.Counter,
    Enterprise,
    Enterprise.Flow,
    Enterprise.Flow.State,
    Document.Block,
    Document.BlockTemplate,
    Document.Comment,
    Document.Pipeline,
    Document.Pipeline.Stage,
    Document.Pipeline.TriggerHistory
  }

  alias WraftDocWeb.AssetUploader

  @doc """
  Create a layout.
  """
  # TODO - improve tests
  @spec create_layout(User.t(), Engine.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def create_layout(%{organisation_id: org_id} = current_user, engine, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})

    current_user
    |> build_assoc(:layouts, engine: engine)
    |> Layout.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, layout} ->
        layout = layout |> layout_files_upload(params)
        layout |> fetch_and_associcate_assets(current_user, params)
        layout |> Repo.preload([:engine, :creator, :assets])

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Upload layout slug file.
  """
  # TODO - write test
  @spec layout_files_upload(Layout.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  def layout_files_upload(layout, %{"slug_file" => _} = params) do
    layout_update_files(layout, params)
  end

  def layout_files_upload(layout, %{"screenshot" => _} = params) do
    layout_update_files(layout, params)
  end

  def layout_files_upload(layout, _params) do
    layout |> Repo.preload([:engine, :creator])
  end

  # Update the layout on fileupload.
  @spec layout_update_files(Layout.t(), map) :: Layout.t() | {:error, Ecto.Changeset.t()}
  defp layout_update_files(layout, params) do
    layout
    |> Layout.file_changeset(params)
    |> Repo.update()
    |> case do
      {:ok, layout} ->
        layout

      {:error, _} = changeset ->
        changeset
    end
  end

  # Get all the assets from their UUIDs and associate them with the given layout.
  defp fetch_and_associcate_assets(layout, current_user, %{"assets" => assets}) do
    (assets || "")
    |> String.split(",")
    |> Stream.map(fn x -> get_asset(x, current_user) end)
    |> Stream.map(fn x -> associate_layout_and_asset(layout, current_user, x) end)
    |> Enum.to_list()
  end

  defp fetch_and_associcate_assets(_layout, _current_user, _params), do: nil

  # Associate the asset with the given layout, ie; insert a LayoutAsset entry.
  defp associate_layout_and_asset(_layout, _current_user, nil), do: nil

  defp associate_layout_and_asset(layout, current_user, asset) do
    layout
    |> build_assoc(:layout_assets, asset: asset, creator: current_user)
    |> LayoutAsset.changeset()
    |> Repo.insert()
  end

  @doc """
  Create a content type.
  """
  # TODO - improve tests
  @spec create_content_type(User.t(), Layout.t(), Flow.t(), map) ::
          ContentType.t() | {:error, Ecto.Changeset.t()}
  def create_content_type(%{organisation_id: org_id} = current_user, layout, flow, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})

    current_user
    |> build_assoc(:content_types, layout: layout, flow: flow)
    |> ContentType.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        content_type |> fetch_and_associate_fields(params, current_user)
        content_type |> Repo.preload([:layout, :flow, {:fields, :field_type}])

      changeset = {:error, _} ->
        changeset
    end
  end

  @spec fetch_and_associate_fields(ContentType.t(), map, User.t()) :: list
  # Iterate throught the list of field types and associate with the content type
  defp fetch_and_associate_fields(content_type, %{"fields" => fields}, user) do
    fields
    |> Stream.map(fn x -> associate_c_type_and_fields(content_type, x, user) end)
    |> Enum.to_list()
  end

  defp fetch_and_associate_fields(_content_type, _params, _user), do: nil

  @spec associate_c_type_and_fields(ContentType.t(), map, User.t()) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()} | nil
  # Fetch and associate field types with the content type
  defp associate_c_type_and_fields(
         c_type,
         %{"key" => key, "field_type_id" => field_type_id},
         user
       ) do
    field_type_id
    |> get_field_type(user)
    |> case do
      %FieldType{} = field_type ->
        field_type
        |> build_assoc(:fields, content_type: c_type)
        |> ContentTypeField.changeset(%{name: key})
        |> Repo.insert()

      nil ->
        nil
    end
  end

  defp associate_c_type_and_fields(_c_type, _field, _user), do: nil

  @doc """
  List all engines.
  """
  # TODO - write tests
  @spec engines_list(map) :: map
  def engines_list(params) do
    Repo.paginate(Engine, params)
  end

  @doc """
  List all layouts.
  """
  # TODO - improve tests
  @spec layout_index(User.t(), map) :: map
  def layout_index(%{organisation_id: org_id}, params) do
    from(l in Layout,
      where: l.organisation_id == ^org_id,
      order_by: [desc: l.id],
      preload: [:engine, :assets]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Show a layout.
  """
  @spec show_layout(binary, User.t()) :: %Layout{engine: Engine.t(), creator: User.t()}
  def show_layout(uuid, user) do
    get_layout(uuid, user)
    |> Repo.preload([:engine, :creator, :assets])
  end

  @doc """
  Get a layout from its UUID.
  """
  @spec get_layout(binary, User.t()) :: Layout.t()
  def get_layout(<<_::288>> = uuid, %{organisation_id: org_id}) do
    Repo.get_by(Layout, uuid: uuid, organisation_id: org_id)
  end

  def get_layout(_, _), do: nil

  @doc """
  Get a layout asset from its layout's and asset's UUIDs.
  """
  # TODO - improve tests
  @spec get_layout_asset(binary, binary) :: LayoutAsset.t()
  def get_layout_asset(l_uuid, a_uuid) do
    from(la in LayoutAsset,
      join: l in Layout,
      where: l.uuid == ^l_uuid,
      join: a in Asset,
      where: a.uuid == ^a_uuid,
      where: la.layout_id == l.id and la.asset_id == a.id
    )
    |> Repo.one()
  end

  @doc """
  Update a layout.
  """
  # TODO - improve tests
  @spec update_layout(Layout.t(), User.t(), map) :: %Layout{engine: Engine.t(), creator: User.t()}
  def update_layout(layout, current_user, %{"engine_uuid" => engine_uuid} = params) do
    %Engine{id: id} = get_engine(engine_uuid)
    {_, params} = Map.pop(params, "engine_uuid")
    params = params |> Map.merge(%{"engine_id" => id})
    update_layout(layout, current_user, params)
  end

  def update_layout(layout, %{id: user_id} = current_user, params) do
    layout
    |> Layout.update_changeset(params)
    |> Spur.update(%{actor: "#{user_id}"})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, layout} ->
        layout |> fetch_and_associcate_assets(current_user, params)
        layout |> Repo.preload([:engine, :creator, :assets])
    end
  end

  @doc """
  Delete a layout.
  """
  # TODO - improve tests
  @spec delete_layout(Layout.t(), User.t()) :: {:ok, Layout.t()} | {:error, Ecto.Changeset.t()}
  def delete_layout(layout, %User{id: id}) do
    layout
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :content_types,
      message:
        "Cannot delete the layout. Some Content types depend on this layout. Update those content types and then try again.!"
    )
    |> Spur.delete(%{actor: "#{id}", meta: layout})
  end

  @doc """
  Delete a layout asset.
  """
  # TODO - improve tests
  @spec delete_layout_asset(LayoutAsset.t(), User.t()) ::
          {:ok, LayoutAsset.t()} | {:error, Ecto.Changeset.t()}
  def delete_layout_asset(layout_asset, %User{id: id}) do
    %{asset: asset} = layout_asset |> Repo.preload([:asset])

    layout_asset
    |> Spur.delete(%{actor: "#{id}", meta: asset})
  end

  @doc """
  List all content types.
  """
  # TODO - improve tests
  @spec content_type_index(User.t(), map) :: map
  def content_type_index(%{organisation_id: org_id}, params) do
    from(ct in ContentType,
      where: ct.organisation_id == ^org_id,
      order_by: [desc: ct.id],
      preload: [:layout, :flow, {:fields, :field_type}]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Show a content type.
  """
  # TODO - improve tests
  @spec show_content_type(User.t(), Ecto.UUID.t()) ::
          %ContentType{layout: Layout.t(), creator: User.t()} | nil
  def show_content_type(user, uuid) do
    user
    |> get_content_type(uuid)
    |> Repo.preload([:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
  end

  @doc """
  Get a content type from its UUID and user's organisation ID.
  """
  # TODO - improve tests
  @spec get_content_type(User.t(), Ecto.UUID.t()) :: ContentType.t() | nil
  def get_content_type(%User{organisation_id: org_id}, <<_::288>> = uuid) do
    Repo.get_by(ContentType, uuid: uuid, organisation_id: org_id)
  end

  def get_content_type(_, _), do: nil

  @doc """
  Get a content type from its ID. Also fetches all its related datas.
  """
  # TODO - write tests
  @spec get_content_type_from_id(integer()) :: %ContentType{layout: %Layout{}, creator: %User{}}
  def get_content_type_from_id(id) do
    Repo.get(ContentType, id)
    |> Repo.preload([:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
  end

  @doc """
  Get a content type field from its UUID.
  """
  # TODO - write tests
  @spec get_content_type_field(binary, User.t()) :: ContentTypeField.t()
  def get_content_type_field(uuid, %{organisation_id: org_id}) do
    from(cf in ContentTypeField,
      where: cf.uuid == ^uuid,
      join: c in ContentType,
      where: c.id == cf.content_type_id and c.organisation_id == ^org_id
    )
    |> Repo.one()
  end

  @doc """
  Update a content type.
  """
  # TODO - write tests
  @spec update_content_type(ContentType.t(), User.t(), map) ::
          %ContentType{
            layout: Layout.t(),
            creator: User.t()
          }
          | {:error, Ecto.Changeset.t()}
  def update_content_type(
        content_type,
        user,
        %{"layout_uuid" => layout_uuid, "flow_uuid" => f_uuid} = params
      ) do
    %Layout{id: id} = get_layout(layout_uuid, user)
    %Flow{id: f_id} = Enterprise.get_flow(f_uuid, user)
    {_, params} = Map.pop(params, "layout_uuid")
    {_, params} = Map.pop(params, "flow_uuid")
    params = params |> Map.merge(%{"layout_id" => id, "flow_id" => f_id})
    update_content_type(content_type, user, params)
  end

  def update_content_type(content_type, %User{id: id} = user, params) do
    content_type
    |> ContentType.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, content_type} ->
        content_type |> fetch_and_associate_fields(params, user)

        content_type
        |> Repo.preload([:layout, :creator, [{:flow, :states}, {:fields, :field_type}]])
    end
  end

  @doc """
  Delete a content type.
  """
  # TODO - write tests
  @spec delete_content_type(ContentType.t(), User.t()) ::
          {:ok, ContentType.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type(content_type, %User{id: id}) do
    content_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the content type. There are many contents under this content type. Delete those contents and try again.!"
    )
    |> Spur.delete(%{actor: "#{id}", meta: content_type})
  end

  @doc """
  Delete a content type field.
  """
  # TODO - improve tests
  @spec delete_content_type_field(ContentTypeField.t(), User.t()) ::
          {:ok, ContentTypeField.t()} | {:error, Ecto.Changeset.t()}
  def delete_content_type_field(content_type_field, %User{id: id}) do
    content_type_field
    |> Spur.delete(%{actor: "#{id}", meta: content_type_field})
  end

  @doc """
  Create a new instance.
  """
  # TODO - improve tests
  @spec create_instance(User.t(), ContentType.t(), State.t(), map) ::
          %Instance{content_type: ContentType.t(), state: State.t()}
          | {:error, Ecto.Changeset.t()}
  def create_instance(current_user, %{id: c_id, prefix: prefix} = c_type, state, params) do
    instance_id = c_id |> create_instance_id(prefix)
    params = params |> Map.merge(%{"instance_id" => instance_id})

    c_type
    |> build_assoc(:instances, state: state, creator: current_user)
    |> Instance.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, content} ->
        Task.start_link(fn -> create_or_update_counter(c_type) end)
        content |> Repo.preload([:content_type, :state])

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Same as create_instance/4, but does not add the insert activity to activity stream.
  """
  # TODO write tests
  @spec create_instance(ContentType.t(), State.t(), map) ::
          %Instance{content_type: ContentType.t(), state: State.t()}
          | {:error, Ecto.Changeset.t()}
  def create_instance(%{id: c_id, prefix: prefix} = c_type, state, params) do
    instance_id = c_id |> create_instance_id(prefix)
    params = params |> Map.merge(%{"instance_id" => instance_id})

    c_type
    |> build_assoc(:instances, state: state)
    |> Instance.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, content} ->
        Task.start_link(fn -> create_or_update_counter(c_type) end)
        content |> Repo.preload([:content_type, :state])

      changeset = {:error, _} ->
        changeset
    end
  end

  # Create Instance ID from the prefix of the content type
  @spec create_instance_id(integer, binary) :: binary
  defp create_instance_id(c_id, prefix) do
    instance_count =
      c_id
      |> get_counter_count_from_content_type_id
      |> add(1)
      |> to_string
      |> String.pad_leading(4, "0")

    concat_strings(prefix, instance_count)
  end

  # Create count of instances created for a content type from its ID
  @spec get_counter_count_from_content_type_id(integer) :: integer
  defp get_counter_count_from_content_type_id(c_type_id) do
    c_type_id
    |> get_counter_from_content_type_id
    |> case do
      nil ->
        0

      %Counter{count: count} ->
        count
    end
  end

  defp get_counter_from_content_type_id(c_type_id) do
    from(c in Counter, where: c.subject == ^"ContentType:#{c_type_id}")
    |> Repo.one()
  end

  @doc """
  Create or update the counter of a content type.integer()
  """
  # TODO - improve tests
  @spec create_or_update_counter(ContentType.t()) :: {:ok, Counter} | {:error, Ecto.Changeset.t()}
  def create_or_update_counter(%ContentType{id: id}) do
    id
    |> get_counter_from_content_type_id
    |> case do
      nil ->
        Counter.changeset(%Counter{}, %{subject: "ContentType:#{id}", count: 1})

      %Counter{count: count} = counter ->
        count = count |> add(1)
        counter |> Counter.changeset(%{count: count})
    end
    |> Repo.insert_or_update()
  end

  # Add two integers
  @spec add(integer, integer) :: integer
  defp add(num1, num2) do
    num1 + num2
  end

  @doc """
  List all instances under an organisation.
  """
  # TODO - improve tests
  @spec instance_index_of_an_organisation(User.t(), map) :: map
  def instance_index_of_an_organisation(%{organisation_id: org_id}, params) do
    from(i in Instance,
      join: u in User,
      where: u.organisation_id == ^org_id and i.creator_id == u.id,
      order_by: [desc: i.id],
      preload: [:content_type, :state]
    )
    |> Repo.paginate(params)
  end

  @doc """
  List all instances under a content types.
  """
  # TODO - improve tests
  @spec instance_index(binary, map) :: map
  def instance_index(c_type_uuid, params) do
    from(i in Instance,
      join: ct in ContentType,
      where: ct.uuid == ^c_type_uuid and i.content_type_id == ct.id,
      order_by: [desc: i.id],
      preload: [:content_type, :state]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Get an instance from its UUID.
  """
  # TODO - improve tests
  @spec get_instance(binary, User.t()) :: Instance.t()
  def get_instance(uuid, %{organisation_id: org_id}) do
    from(i in Instance,
      where: i.uuid == ^uuid,
      join: c in ContentType,
      where: c.id == i.content_type_id and c.organisation_id == ^org_id
    )
    |> Repo.one()
    |> Repo.preload([:state])

    # Repo.get_by(Instance, uuid: uuid) |> Repo.preload([:state])
  end

  @doc """
  Show an instance.
  """
  # TODO - improve tests
  @spec show_instance(binary, User.t()) ::
          %Instance{creator: User.t(), content_type: ContentType.t(), state: State.t()} | nil
  def show_instance(instance_uuid, user) do
    instance_uuid
    |> get_instance(user)
    |> Repo.preload([:creator, [{:content_type, :layout}], :state])
    |> get_built_document()
  end

  @doc """
  Get the build document of the given instance.
  """
  # TODO - write tests
  @spec get_built_document(Instance.t()) :: Instance.t() | nil
  def get_built_document(%{id: id, instance_id: instance_id} = instance) do
    from(h in History,
      where: h.exit_code == 0,
      where: h.content_id == ^id,
      order_by: [desc: h.inserted_at],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil ->
        instance

      %History{} ->
        doc_url = "uploads/contents/#{instance_id}/final.pdf"
        instance |> Map.put(:build, doc_url)
    end
  end

  def get_built_document(nil), do: nil

  @doc """
  Update an instance.
  """
  # TODO - improve tests
  @spec update_instance(Instance.t(), User.t(), map) ::
          %Instance{content_type: ContentType.t(), state: State.t(), creator: Creator.t()}
          | {:error, Ecto.Changeset.t()}
  def update_instance(old_instance, %User{id: id} = current_user, params) do
    old_instance
    |> Instance.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:ok, instance} ->
        Task.start_link(fn -> create_version(current_user, old_instance, instance) end)

        instance
        |> Repo.preload([:creator, [{:content_type, :layout}], :state])
        |> get_built_document()

      {:error, _} = changeset ->
        changeset
    end
  end

  # Create a new version with old data, when an instance is updated.
  # The previous data will be stored in the versions. Latest one will
  # be in the content.
  # A new version is added only if there is any difference in either the
  # raw or serialized fields of the instances.
  @spec create_version(User.t(), Instance.t(), Instance.t()) ::
          {:ok, Version.t()} | {:error, Ecto.Changeset.t()}
  defp create_version(current_user, old_instance, new_instance) do
    case instance_updated?(old_instance, new_instance) do
      true ->
        params = create_version_params(old_instance)

        current_user
        |> build_assoc(:instance_versions, content: old_instance)
        |> Version.changeset(params)
        |> Repo.insert()

      false ->
        nil
    end
  end

  # Create the params to create a new version.
  @spec create_version_params(Instance.t()) :: map
  defp create_version_params(%Instance{id: id} = instance) do
    version =
      from(v in Version,
        where: v.content_id == ^id,
        order_by: [desc: v.inserted_at],
        limit: 1,
        select: v.version_number
      )
      |> Repo.one()
      |> case do
        nil ->
          1

        version ->
          version + 1
      end

    instance |> Map.from_struct() |> Map.put(:version_number, version)
  end

  # Checks whether the raw and serialzed of old and new instances are same or not.
  # If they are both the same, returns false, else returns true
  @spec instance_updated?(Instance.t(), Instance.t()) :: boolean
  defp instance_updated?(%{raw: raw, serialized: map}, %{raw: raw, serialized: map}), do: false

  defp instance_updated?(_old_instance, _new_instance), do: true

  @doc """
  Update instance's state if the flow IDs of both
  the new state and the instance's content type are same.
  """
  # TODO - impove tests
  @spec update_instance_state(User.t(), Instance.t(), State.t()) ::
          Instance.t() | {:error, Ecto.Changeset.t()} | {:error, :wrong_flow}
  def update_instance_state(%{id: user_id}, instance, %{
        id: state_id,
        state: new_state,
        flow_id: flow_id
      }) do
    %{content_type: %{flow_id: f_id}, state: %{state: state}} =
      instance |> Repo.preload([:content_type, :state])

    cond do
      flow_id == f_id ->
        instance_state_upadate(instance, user_id, state_id, state, new_state)

      true ->
        {:error, :wrong_flow}
    end
  end

  @doc """
  Update instance's state. Also add the from and to state of in the activity meta.
  """
  # TODO - write tests
  @spec instance_state_upadate(Instance.t(), integer, integer, String.t(), String.t()) ::
          Instance.t() | {:error, Ecto.Changeset.t()}
  def instance_state_upadate(instance, user_id, state_id, old_state, new_state) do
    instance
    |> Instance.update_state_changeset(%{state_id: state_id})
    |> Spur.update(%{
      actor: "#{user_id}",
      object: "Instance-State:#{instance.id}",
      meta: %{from: old_state, to: new_state}
    })
    |> case do
      {:ok, instance} ->
        instance
        |> Repo.preload([:creator, [{:content_type, :layout}], :state])
        |> get_built_document()

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete an instance.
  """
  # TODO - write tests
  @spec delete_instance(Instance.t(), User.t()) ::
          {:ok, Instance.t()} | {:error, Ecto.Changeset.t()}
  def delete_instance(instance, %User{id: id}) do
    instance
    |> Spur.delete(%{actor: "#{id}", meta: instance})
  end

  @doc """
  Get an engine from its UUID.
  """
  # TODO - improve tests
  @spec get_engine(binary) :: Engine.t() | nil
  def get_engine(engine_uuid) do
    Repo.get_by(Engine, uuid: engine_uuid)
  end

  @doc """
  Create a theme.
  """
  # TODO Improve tests
  @spec create_theme(User.t(), map) :: {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def create_theme(%{organisation_id: org_id} = current_user, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})

    current_user
    |> build_assoc(:themes)
    |> Theme.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, theme} ->
        theme |> theme_file_upload(params)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Upload theme file.
  """
  # TODO - write tests
  @spec theme_file_upload(Theme.t(), map) :: {:ok, %Theme{}} | {:error, Ecto.Changeset.t()}
  def theme_file_upload(theme, %{"file" => _} = params) do
    theme |> Theme.file_changeset(params) |> Repo.update()
  end

  def theme_file_upload(theme, _params) do
    {:ok, theme}
  end

  @doc """
  Index of themes inside current user's organisation.
  """
  # TODO - improve tests
  @spec theme_index(User.t(), map) :: map
  def theme_index(%User{organisation_id: org_id}, params) do
    from(t in Theme, where: t.organisation_id == ^org_id, order_by: [desc: t.id])
    |> Repo.paginate(params)
  end

  @doc """
  Get a theme from its UUID.
  """
  # TODO - improve test
  @spec get_theme(binary, User.t()) :: Theme.t() | nil
  def get_theme(theme_uuid, %{organisation_id: org_id}) do
    Repo.get_by(Theme, uuid: theme_uuid, organisation_id: org_id)
  end

  @doc """
  Show a theme.
  """
  # TODO - improve test
  @spec show_theme(binary, User.t()) :: %Theme{creator: User.t()} | nil
  def show_theme(theme_uuid, user) do
    theme_uuid |> get_theme(user) |> Repo.preload([:creator])
  end

  @doc """
  Update a theme.
  """
  # TODO - improve test
  @spec update_theme(Theme.t(), User.t(), map) :: {:ok, Theme.t()} | {:error, Ecto.Changeset.t()}
  def update_theme(theme, %User{id: id}, params) do
    theme |> Theme.update_changeset(params) |> Spur.update(%{actor: "#{id}"})
  end

  @doc """
  Delete a theme.
  """
  # TODO - improve test
  @spec delete_theme(Theme.t(), User.t()) :: {:ok, Theme.t()}
  def delete_theme(theme, %User{id: id}) do
    theme
    |> Spur.delete(%{actor: "#{id}", meta: theme})
  end

  @doc """
  Create a data template.
  """
  @spec create_data_template(User.t(), ContentType.t(), map) ::
          {:ok, DataTemplate.t()} | {:error, Ecto.Changeset.t()}
  # TODO - imprvove tests
  def create_data_template(current_user, c_type, params) do
    current_user
    |> build_assoc(:data_templates, content_type: c_type)
    |> DataTemplate.changeset(params)
    |> Spur.insert()
  end

  @doc """
  List all data templates under a content types.
  """
  # TODO - imprvove tests
  @spec data_template_index(binary, map) :: map
  def data_template_index(c_type_uuid, params) do
    from(dt in DataTemplate,
      join: ct in ContentType,
      where: ct.uuid == ^c_type_uuid and dt.content_type_id == ct.id,
      order_by: [desc: dt.id],
      preload: [:content_type]
    )
    |> Repo.paginate(params)
  end

  @doc """
  List all data templates under current user's organisation.
  """
  # TODO - imprvove tests
  @spec data_templates_index_of_an_organisation(User.t(), map) :: map
  def data_templates_index_of_an_organisation(%{organisation_id: org_id}, params) do
    from(dt in DataTemplate,
      join: u in User,
      where: u.organisation_id == ^org_id and dt.creator_id == u.id,
      order_by: [desc: dt.id],
      preload: [:content_type]
    )
    |> Repo.paginate(params)
  end

  @doc """
  Get a data template from its uuid and organisation ID of user.
  """
  # TODO - imprvove tests
  @spec get_d_template(User.t(), Ecto.UUID.t()) :: DataTemplat.t() | nil
  def get_d_template(%User{organisation_id: org_id}, <<_::288>> = d_temp_uuid) do
    from(d in DataTemplate,
      where: d.uuid == ^d_temp_uuid,
      join: c in ContentType,
      where: c.id == d.content_type_id and c.organisation_id == ^org_id
    )
    |> Repo.one()
  end

  def get_d_template(_, _), do: nil

  @doc """
  Show a data template.
  """
  # TODO - imprvove tests
  @spec show_d_template(User.t(), Ecto.UUID.t()) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()} | nil
  def show_d_template(user, d_temp_uuid) do
    user |> get_d_template(d_temp_uuid) |> Repo.preload([:creator, :content_type])
  end

  @doc """
  Update a data template
  """
  # TODO - imprvove tests
  @spec update_data_template(DataTemplate.t(), User.t(), map) ::
          %DataTemplate{creator: User.t(), content_type: ContentType.t()}
          | {:error, Ecto.Changeset.t()}
  def update_data_template(d_temp, %User{id: id}, params) do
    d_temp
    |> DataTemplate.changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:ok, d_temp} ->
        d_temp |> Repo.preload([:creator, :content_type])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a data template
  """
  # TODO - imprvove tests
  @spec delete_data_template(DataTemplate.t(), User.t()) :: {:ok, DataTemplate.t()}
  def delete_data_template(d_temp, %User{id: id}) do
    d_temp |> Spur.delete(%{actor: "#{id}", meta: d_temp})
  end

  @doc """
  Create an asset.
  """
  # TODO - imprvove tests
  @spec create_asset(User.t(), map) :: {:ok, Asset.t()}
  def create_asset(%{organisation_id: org_id} = current_user, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})

    current_user
    |> build_assoc(:assets)
    |> Asset.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, asset} ->
        asset |> asset_file_upload(params)

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Upload asset file.
  """
  # TODO - write tests
  @spec asset_file_upload(Asset.t(), map) :: {:ok, %Asset{}} | {:error, Ecto.Changeset.t()}
  def asset_file_upload(asset, %{"file" => _} = params) do
    asset |> Asset.file_changeset(params) |> Repo.update()
  end

  def asset_file_upload(asset, _params) do
    {:ok, asset}
  end

  @doc """
  Index of all assets in an organisation.
  """
  # TODO - improve tests
  @spec asset_index(integer, map) :: map
  def asset_index(organisation_id, params) do
    from(a in Asset, where: a.organisation_id == ^organisation_id, order_by: [desc: a.id])
    |> Repo.paginate(params)
  end

  @doc """
  Show an asset.
  """
  # TODO - improve tests
  @spec show_asset(binary, User.t()) :: %Asset{creator: User.t()}
  def show_asset(asset_uuid, user) do
    asset_uuid
    |> get_asset(user)
    |> Repo.preload([:creator])
  end

  @doc """
  Get an asset from its UUID.
  """
  # TODO - improve tests
  @spec get_asset(binary, User.t()) :: Asset.t()
  def get_asset(uuid, %{organisation_id: org_id}) do
    Repo.get_by(Asset, uuid: uuid, organisation_id: org_id)
  end

  @doc """
  Update an asset.
  """
  # TODO - improve tests
  @spec update_asset(Asset.t(), User.t(), map) :: {:ok, Asset.t()}
  def update_asset(asset, %User{id: id}, params) do
    asset |> Asset.update_changeset(params) |> Spur.update(%{actor: "#{id}"})
  end

  @doc """
  Delete an asset.
  """
  @spec delete_asset(Asset.t(), User.t()) :: {:ok, Asset.t()}
  def delete_asset(asset, %User{id: id}) do
    asset |> Spur.delete(%{actor: "#{id}", meta: asset})
  end

  @doc """
  Preload assets of a layout.
  """
  # TODO - write tests
  @spec preload_asset(Layout.t()) :: Layout.t()
  def preload_asset(layout) do
    layout |> Repo.preload([:assets])
  end

  @doc """
  Build a PDF document.
  """
  # TODO - write tests
  @spec build_doc(Instance.t(), Layout.t()) :: {any, integer}
  def build_doc(%Instance{instance_id: u_id, content_type: c_type} = instance, %Layout{
        slug: slug,
        assets: assets
      }) do
    File.mkdir_p("uploads/contents/#{u_id}")
    System.cmd("cp", ["-a", "lib/slugs/#{slug}/.", "uploads/contents/#{u_id}"])
    task = Task.async(fn -> generate_qr(instance) end)
    Task.start(fn -> move_old_builds(u_id) end)
    c_type = c_type |> Repo.preload([:fields])

    header =
      c_type.fields
      |> Enum.reduce("--- \n", fn x, acc ->
        find_header_values(x, instance.serialized, acc)
      end)

    header = assets |> Enum.reduce(header, fn x, acc -> find_header_values(x, acc) end)
    qr_code = Task.await(task)
    page_title = instance.serialized["title"]

    header =
      header
      |> concat_strings("qrcode: #{qr_code} \n")
      |> concat_strings("path: uploads/contents/#{u_id}\n")
      |> concat_strings("title: #{page_title}\n")
      |> concat_strings("id: #{u_id}\n")
      |> concat_strings("--- \n")

    content = """
    #{header}
    #{instance.raw}
    """

    File.write("uploads/contents/#{u_id}/content.md", content)

    pandoc_commands = [
      "uploads/contents/#{u_id}/content.md",
      "--template=uploads/contents/#{u_id}/template.tex",
      "--pdf-engine=xelatex",
      "-o",
      "uploads/contents/#{u_id}/final.pdf"
    ]

    System.cmd("pandoc", pandoc_commands)
  end

  # Find the header values for the content.md file from the serialized data of an instance.
  @spec find_header_values(ContentTypeField.t(), map, String.t()) :: String.t()
  defp find_header_values(%ContentTypeField{name: key}, serialized, acc) do
    serialized
    |> Enum.find(fn {k, _} -> k == key end)
    |> case do
      nil ->
        acc

      {_, value} ->
        concat_strings(acc, "#{key}: #{value} \n")
    end
  end

  # Find the header values for the content.md file from the assets of the layout used.
  @spec find_header_values(Asset.t(), String.t()) :: String.t()
  defp find_header_values(%Asset{name: name, file: file} = asset, acc) do
    <<_first::utf8, rest::binary>> = AssetUploader |> generate_url(file, asset)
    concat_strings(acc, "#{name}: #{rest} \n")
  end

  # Generate url.
  @spec generate_url(any, String.t(), map) :: String.t()
  defp generate_url(uploader, file, scope) do
    uploader.url({file, scope}, signed: true)
  end

  # Generate QR code with the UUID of the given Instance.
  @spec generate_qr(Instance.t()) :: String.t()
  defp generate_qr(%Instance{uuid: uuid, instance_id: i_id}) do
    qr_code_png =
      uuid
      |> EQRCode.encode()
      |> EQRCode.png()

    destination = "uploads/contents/#{i_id}/qr.png"
    File.write(destination, qr_code_png, [:binary])
    destination
  end

  # Concat two strings.
  @spec concat_strings(String.t(), String.t()) :: String.t()
  defp concat_strings(string1, string2) do
    string1 <> string2
  end

  # Move old builds to the history folder
  @spec move_old_builds(String.t()) :: {:ok, non_neg_integer()}
  defp move_old_builds(u_id) do
    path = "uploads/contents/#{u_id}/"
    history_path = concat_strings(path, "history/")
    old_file = concat_strings(path, "final.pdf")
    File.mkdir_p(history_path)

    history_file =
      history_path
      |> File.ls!()
      |> Enum.sort(:desc)
      |> case do
        ["final-" <> version | _] ->
          ["v" <> version | _] = version |> String.split(".pdf")
          version = version |> String.to_integer() |> add(1)
          concat_strings(history_path, "final-v#{version}.pdf")

        [] ->
          concat_strings(history_path, "final-v1.pdf")
      end

    File.copy(old_file, history_file)
  end

  @doc """
  Insert the build history of the given instance.
  """
  # TODO - write tests
  @spec add_build_history(User.t(), Instance.t(), map) :: History.t()
  def add_build_history(current_user, instance, params) do
    params = create_build_history_params(params)

    current_user
    |> build_assoc(:build_histories, content: instance)
    |> History.changeset(params)
    |> Repo.insert!()
  end

  @doc """
  Same as add_build_history/3, but creator will not be stored.
  """
  # TODO - write tests
  @spec add_build_history(Instance.t(), map) :: History.t()
  def add_build_history(instance, params) do
    params = create_build_history_params(params)

    instance
    |> build_assoc(:build_histories)
    |> History.changeset(params)
    |> Repo.insert!()
  end

  # Create params to insert build history
  # Build history Status will be "success" when exit code is 0
  @spec create_build_history_params(map) :: map
  defp create_build_history_params(%{exit_code: exit_code} = params) when exit_code == 0 do
    %{status: "success"} |> Map.merge(params) |> calculate_build_delay
  end

  # Build history Status will be "failed" when exit code is not 0
  defp create_build_history_params(params) do
    %{status: "failed"} |> Map.merge(params) |> calculate_build_delay
  end

  # Calculate the delay in the build process from the start and end time in the params.
  @spec calculate_build_delay(map) :: map
  defp calculate_build_delay(%{start_time: start_time, end_time: end_time} = params) do
    delay = Timex.diff(end_time, start_time, :millisecond)
    params |> Map.merge(%{delay: delay})
  end

  @doc """
  Create a Block
  """
  # TODO - write tests
  @spec create_block(User.t(), map) :: Block.t()
  def create_block(%{organisation_id: org_id} = current_user, params) do
    params = params |> Map.merge(%{"organisation_id" => org_id})

    current_user
    |> build_assoc(:blocks)
    |> Block.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, block} ->
        block

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Get a block by id
  """
  # TODO - write tests
  @spec get_block(Ecto.UUID.t(), User.t()) :: Block.t()
  def get_block(uuid, %{organisation_id: org_id}) do
    Block |> Repo.get_by(uuid: uuid, organisation_id: org_id)
  end

  @doc """
  Update a block
  """
  # TODO - write tests
  def update_block(%Block{} = block, params) do
    block
    |> Block.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, block} ->
        block

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Delete a block
  """
  # TODO - write tests
  def delete_block(%Block{} = block) do
    block
    |> Repo.delete()
  end

  @doc """
  Function to generate charts from diffrent endpoints as per input example api: https://quickchart.io/chart/create
  """
  # TODO - write tests
  @spec generate_chart(map) :: map
  def generate_chart(%{"btype" => "gantt"}) do
    %{"url" => "gant_chart_url"}
  end

  def generate_chart(%{
        "dataset" => dataset,
        "api_route" => api_route,
        "endpoint" => "quick_chart"
      }) do
    %HTTPoison.Response{body: response_body} =
      HTTPoison.post!(api_route,
        body: Poison.encode!(dataset),
        headers: [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
      )

    Poison.decode!(response_body)
  end

  def generate_chart(%{"dataset" => dataset, "api_route" => api_route, "endpoint" => "blocks_api"}) do
    %HTTPoison.Response{body: response_body} =
      HTTPoison.post!(
        api_route,
        Poison.encode!(dataset),
        [{"Accept", "application./json"}, {"Content-Type", "application/json"}]
      )

    Poison.decode!(response_body)
  end

  def generate_chart(_params) do
    %{"status" => false, "error" => "invalid endpoint"}
  end

  @spec generate_tex_chart(map) :: <<_::64, _::_*8>>
  @doc """
  Generate tex code for the chart
  """
  # TODO - write tests
  def generate_tex_chart(%{"dataset" => dataset, "btype" => "gantt"}) do
    generate_tex_gantt_chart(dataset)
  end

  def generate_tex_chart(%{"dataset" => %{"data" => data}}) do
    "\\pie [rotate = 180 ]{#{tex_chart(data, "")}}"
  end

  defp tex_chart([%{"value" => value, "label" => label} | []], tex_chart) do
    "#{tex_chart}#{value}/#{label}"
  end

  defp tex_chart([%{"value" => value, "label" => label} | datas], tex_chart) do
    tex_chart = "#{tex_chart}#{value}/#{label}, "
    tex_chart(datas, tex_chart)
  end

  @doc """
  Generate latex of ganttchart
  """
  def generate_tex_gantt_chart(%{
        "caption" => caption,
        "title_list" => %{"start" => tl_start, "end" => tl_end},
        "data" => data
      }) do
    "\\documentclass[a4paper, 12pt,fleqn]{article}
      \\usepackage{pgfgantt}

        \\begin{document}
        \\begin{figure}
        \\centering
        \\begin{ganttchart}[%inline,bar inline label anchor=west,bar inline label node/.append style={anchor=west, text=white},bar/.append style={fill=cyan!90!black,},bar height=.8,]
        {#{tl_start}}{#{tl_end}}
        \\gantttitlelist{#{tl_start},...,#{tl_end}}{1}\\
        #{gant_bar(data, "", tl_end)}
        \\end{ganttchart}
        \\caption{#{caption}}
        \\end{figure}
        \\end{document}
        "
  end

  # Generate bar for gant chart
  defp gant_bar(
         [%{"label" => label, "start" => b_start, "end" => b_end, "bar" => bar} | data],
         g_bar,
         tl_end
       ) do
    gant_bar(data, "#{g_bar}\\ganttbar[inline=false]{#{label}}{#{b_start}}{#{b_end}}
     #{inline_gant_bar(bar, "", "", tl_end)}
    ", tl_end)
  end

  defp gant_bar([], g_bar, _tl_end) do
    g_bar
  end

  # Generate inline bar for gant chart
  defp inline_gant_bar(
         [%{"label" => label, "start" => b_start, "end" => b_end} | data],
         ig_bar,
         _b_end,
         tl_end
       ) do
    inline_gant_bar(data, "#{ig_bar}\\ganttbar{#{label}}{#{b_start}}{#{b_end}}", b_end, tl_end)
  end

  defp inline_gant_bar([], ig_bar, b_end, tl_end) do
    "#{ig_bar}
    \\ganttbar{}{#{b_end}}{#{tl_end}}\\"
  end

  # defp tex_chart([], tex_chart) do
  #   tex_chart
  # end

  @doc """
  Create a field type
  """
  # TODO - write tests
  @spec create_field_type(User.t(), map) :: {:ok, FieldType.t()}
  def create_field_type(current_user, params) do
    current_user
    |> build_assoc(:field_types)
    |> FieldType.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Index of all field types.
  """
  # TODO - write tests
  @spec field_type_index(map) :: map
  def field_type_index(params) do
    from(ft in FieldType, order_by: [desc: ft.id])
    |> Repo.paginate(params)
  end

  @doc """
  Get a field type from its UUID.
  """
  # TODO - write tests
  @spec get_field_type(binary, User.t()) :: FieldType.t()
  def get_field_type(field_type_uuid, %{organisation_id: org_id}) do
    from(ft in FieldType,
      where: ft.uuid == ^field_type_uuid,
      join: u in User,
      where: u.id == ft.creator_id and u.organisation_id == ^org_id
    )
    |> Repo.one()

    # Repo.get_by(FieldType, uuid: field_type_uuid, organisation_id: org_id)
  end

  @doc """
  Update a field type
  """
  # TODO - write tests
  @spec update_field_type(FieldType.t(), map) :: FieldType.t() | {:error, Ecto.Changeset.t()}
  def update_field_type(field_type, params) do
    field_type
    |> FieldType.changeset(params)
    |> Repo.update()
  end

  @doc """
  Deleta a field type
  """
  # TODO - write tests
  @spec delete_field_type(FieldType.t()) :: {:ok, FieldType.t()} | {:error, Ecto.Changeset.t()}
  def delete_field_type(field_type) do
    field_type
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.no_assoc_constraint(
      :fields,
      message:
        "Cannot delete the field type. Some Content types depend on this field type. Update those content types and then try again.!"
    )
    |> Repo.delete()
  end

  @doc """
  Create a background job for Bulk build.
  """
  @spec insert_bulk_build_work(User.t(), binary(), binary(), binary(), map, Plug.Upload.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_bulk_build_work(
        %User{} = current_user,
        <<_::288>> = c_type_uuid,
        <<_::288>> = state_uuid,
        <<_::288>> = d_temp_uuid,
        mapping,
        %{
          filename: filename,
          path: path
        }
      ) do
    File.mkdir_p("temp/bulk_build_source/")
    dest_path = "temp/bulk_build_source/#{filename}"
    System.cmd("cp", [path, dest_path])

    %{
      user_uuid: current_user.uuid,
      c_type_uuid: c_type_uuid,
      state_uuid: state_uuid,
      d_temp_uuid: d_temp_uuid,
      mapping: mapping,
      file: dest_path
    }
    |> create_bulk_job()
  end

  def insert_bulk_build_work(_, _, _, _, _, _), do: nil

  @doc """
  Create a background job for data template bulk import.
  """
  @spec insert_data_template_bulk_import_work(binary, binary, map, Plug.Uploap.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_data_template_bulk_import_work(
        <<_::288>> = user_uuid,
        <<_::288>> = c_type_uuid,
        mapping,
        %Plug.Upload{
          filename: filename,
          path: path
        }
      ) do
    File.mkdir_p("temp/bulk_import_source/d_template")
    dest_path = "temp/bulk_import_source/d_template/#{filename}"
    System.cmd("cp", [path, dest_path])

    %{
      user_uuid: user_uuid,
      c_type_uuid: c_type_uuid,
      mapping: mapping,
      file: dest_path
    }
    |> create_bulk_job(["data template"])
  end

  def insert_data_template_bulk_import_work(_, _, _, _), do: nil

  @doc """
  Creates a background job for block template bulk import.
  """
  @spec insert_block_template_bulk_import_work(binary, map, Plug.Uploap.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def insert_block_template_bulk_import_work(<<_::288>> = user_uuid, mapping, %Plug.Upload{
        filename: filename,
        path: path
      }) do
    File.mkdir_p("temp/bulk_import_source/b_template")
    dest_path = "temp/bulk_import_source/b_template/#{filename}"
    System.cmd("cp", [path, dest_path])

    %{
      user_uuid: user_uuid,
      mapping: mapping,
      file: dest_path
    }
    |> create_bulk_job(["block template"])
  end

  def insert_block_template_bulk_import_work(_, _, _), do: nil

  @doc """
  Creates a background job to run a pipeline.
  """
  # TODO - write tests
  @spec create_pipeline_job(TriggerHistory.t()) ::
          {:error, Ecto.Changeset.t()} | {:ok, Oban.Job.t()}
  def create_pipeline_job(%TriggerHistory{} = trigger_history) do
    trigger_history |> create_bulk_job(["pipeline_job"])
  end

  def create_pipeline_job(_, _), do: nil

  defp create_bulk_job(args, tags \\ []) do
    args
    |> WraftDocWeb.Worker.BulkWorker.new(tags: tags)
    |> Oban.insert()
  end

  @doc """
  Bulk build function.
  """
  # TODO - write tests
  @spec bulk_doc_build(User.t(), ContentType.t(), State.t(), DataTemplate.t(), map, String.t()) ::
          list | {:error, :not_found}
  def bulk_doc_build(
        %User{} = current_user,
        %ContentType{} = c_type,
        %State{} = state,
        %DataTemplate{} = d_temp,
        mapping,
        path
      ) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = mapping |> Map.keys()

    c_type = c_type |> Repo.preload([{:layout, :assets}])

    path
    |> decode_csv(mapping_keys)
    |> Enum.map(fn x ->
      create_instance_params_for_bulk_build(x, d_temp, current_user, c_type, state, mapping)
    end)
    |> Stream.map(fn x -> bulk_build(current_user, x, c_type.layout) end)
    |> Enum.to_list()
  end

  def bulk_doc_build(_user, _c_type, _state, _d_temp, _mapping, _path) do
    {:error, :not_found}
  end

  @spec create_instance_params_for_bulk_build(
          map,
          DataTemplate.t(),
          User.t(),
          ContentType.t(),
          State.t(),
          map
        ) :: Instance.t()
  defp create_instance_params_for_bulk_build(
         serialized,
         %DataTemplate{} = d_temp,
         current_user,
         c_type,
         state,
         mapping
       ) do
    # The serialzed map's keys are changed to the values in the mapping. These
    # values are actually the fields of the content type.
    # This updated serialzed is then reduced to get the raw data
    # by replacing the variables in the data template.
    serialized = serialized |> update_keys(mapping)
    params = do_create_instance_params(serialized, d_temp)
    type = Instance.types()[:bulk_build]
    params = params |> Map.put("type", type)
    create_instance_for_bulk_build(current_user, c_type, state, params)
  end

  @doc """
  Generate params to create instance.
  """
  # TODO - write tests
  @spec do_create_instance_params(map, DataTemplate.t()) :: map
  def do_create_instance_params(serialized, %{title_template: title_temp, data: template}) do
    title =
      serialized
      |> Enum.reduce(title_temp, fn {k, v}, acc ->
        WraftDoc.DocConversion.replace_content(k, v, acc)
      end)

    serialized = serialized |> Map.put("title", title)

    raw =
      serialized
      |> Enum.reduce(template, fn {k, v}, acc ->
        WraftDoc.DocConversion.replace_content(k, v, acc)
      end)

    %{"raw" => raw, "serialized" => serialized}
  end

  # Create instance for bulk build. Uses the `create_instance/4` function
  # to create the instances. But the functions is run until the instance is created successfully.
  # Since we are iterating over list of params to create instances, there is a high chance of
  # unique ID of instances to repeat and hence for instance creation failures. This is why
  # we loop the fucntion until instance is successfully created.
  @spec create_instance_for_bulk_build(User.t(), ContentType.t(), State.t(), map) :: Instance.t()
  defp create_instance_for_bulk_build(current_user, c_type, state, params) do
    create_instance(current_user, c_type, state, params)
    |> case do
      %Instance{} = instance ->
        instance

      _ ->
        create_instance_for_bulk_build(current_user, c_type, state, params)
    end
  end

  @doc """
  Builds the doc using `build_doc/2`.
  Here we also records the build history using `add_build_history/3`.
  """
  # TODO - write tests
  @spec bulk_build(User.t(), Instance.t(), Layout.t()) :: tuple
  def bulk_build(current_user, instance, layout) do
    start_time = Timex.now()
    {result, exit_code} = build_doc(instance, layout)
    end_time = Timex.now()

    add_build_history(current_user, instance, %{
      start_time: start_time,
      end_time: end_time,
      exit_code: exit_code
    })

    {result, exit_code}
  end

  @doc """
  Same as bulk_buil/3, but does not store the creator in build history.
  """
  # TODO - write tests
  @spec bulk_build(Instance.t(), Layout.t()) :: {Collectable.t(), non_neg_integer()}
  def bulk_build(instance, layout) do
    start_time = Timex.now()
    {result, exit_code} = build_doc(instance, layout)
    end_time = Timex.now()

    add_build_history(instance, %{
      start_time: start_time,
      end_time: end_time,
      exit_code: exit_code
    })

    {result, exit_code}
  end

  # Change the Keys of the CSV decoded map to the values of the mapping.
  @spec update_keys(map, map) :: map
  defp update_keys(map, mapping) do
    # new_map =
    Enum.reduce(mapping, %{}, fn {k, v}, acc ->
      value = Map.get(map, k)
      acc |> Map.put(v, value)
    end)

    # keys = mapping |> Map.keys()
    # map |> Map.drop(keys) |> Map.merge(new_map)
  end

  @doc """
  Creates data templates in bulk from the file given.
  """
  ## TODO - improve tests
  @spec data_template_bulk_insert(User.t(), ContentType.t(), map, String.t()) ::
          [{:ok, DataTemplate.t()}] | {:error, :not_found}
  def data_template_bulk_insert(%User{} = current_user, %ContentType{} = c_type, mapping, path) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = mapping |> Map.keys()

    path
    |> decode_csv(mapping_keys)
    |> Stream.map(fn x -> bulk_d_temp_creation(x, current_user, c_type, mapping) end)
    |> Enum.to_list()
  end

  def data_template_bulk_insert(_, _, _, _), do: {:error, :not_found}

  @spec bulk_d_temp_creation(map, User.t(), ContentType.t(), map) :: {:ok, DataTemplate.t()}
  defp bulk_d_temp_creation(data, user, c_type, mapping) do
    params = data |> update_keys(mapping)
    create_data_template(user, c_type, params)
  end

  @doc """
  Creates block templates in bulk from the file given.
  """
  @spec block_template_bulk_insert(User.t(), map, String.t()) ::
          [{:ok, BlockTemplate.t()}] | {:error, :not_found}
  ## TODO - improve tests
  def block_template_bulk_insert(%User{} = current_user, mapping, path) do
    # TODO Map will be arranged in the ascending order
    # of keys. This causes unexpected changes in decoded CSV
    mapping_keys = mapping |> Map.keys()

    path
    |> decode_csv(mapping_keys)
    |> Stream.map(fn x -> bulk_b_temp_creation(x, current_user, mapping) end)
    |> Enum.to_list()
  end

  def block_template_bulk_insert(_, _, _), do: {:error, :not_found}

  # Decode the given CSV file using the headers values
  # First argument is the path of the file
  # Second argument is the headers.
  @spec decode_csv(String.t(), list) :: list
  defp decode_csv(path, mapping_keys) do
    File.stream!(path)
    |> Stream.drop(1)
    |> CSV.decode!(headers: mapping_keys)
    |> Enum.to_list()
  end

  @spec bulk_b_temp_creation(map, User.t(), map) :: BlockTemplate.t()
  defp bulk_b_temp_creation(data, user, mapping) do
    params = data |> update_keys(mapping)
    create_block_template(user, params)
  end

  @doc """
  Create a block template
  """
  # TODO - improve tests
  @spec create_block_template(User.t(), map) :: BlockTemplate.t()
  def create_block_template(%{organisation_id: org_id} = current_user, params) do
    current_user
    |> build_assoc(:block_templates, organisation_id: org_id)
    |> BlockTemplate.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, block_template} ->
        block_template

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Get a block template by its uuid
  """
  # TODO - write tests
  @spec get_block_template(Ecto.UUID.t(), User.t()) :: BlockTemplate.t()
  def get_block_template(uuid, %{organisation_id: org_id}) do
    BlockTemplate
    |> Repo.get_by(uuid: uuid, organisation_id: org_id)
  end

  @doc """
  Updates a block template
  """
  # TODO - write tests
  @spec update_block_template(User.t(), BlockTemplate.t(), map) :: BlockTemplate.t()
  def update_block_template(%User{id: id}, block_template, params) do
    block_template
    |> BlockTemplate.update_changeset(params)
    |> Spur.update(%{actor: "#{id}"})
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, block_template} ->
        block_template
    end
  end

  @doc """
  Delete a block template by uuid
  """
  # TODO - write tests
  @spec delete_block_template(User.t(), BlockTemplate.t()) :: BlockTemplate.t()
  def delete_block_template(%User{id: id}, %BlockTemplate{} = block_template) do
    block_template
    |> Spur.delete(%{actor: "#{id}", meta: block_template})
  end

  @doc """
  Index of a block template by organisation
  """
  # TODO - write tests
  @spec block_template_index(User.t(), map) :: List.t()
  def block_template_index(%{organisation_id: org_id}, params) do
    from(bt in BlockTemplate, where: bt.organisation_id == ^org_id, order_by: [desc: bt.id])
    |> Repo.paginate(params)
  end

  @doc """
  Create a comment
  """
  # TODO - improve tests
  def create_comment(%{organisation_id: org_id} = current_user, params \\ %{}) do
    params = Map.put(params, "organisation_id", org_id)

    current_user
    |> build_assoc(:comments)
    |> Comment.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment |> Repo.preload([{:user, :profile}])

      {:error, _} = changeset ->
        changeset
    end
  end

  @doc """
  Get a comment by uuid.
  """
  # TODO - improve tests
  @spec get_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def get_comment(<<_::288>> = uuid, %{organisation_id: org_id}) do
    Comment
    |> Repo.get_by(uuid: uuid, organisation_id: org_id)
  end

  @doc """
  Fetch a comment and all its details.
  """
  # TODO - improve tests
  @spec show_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def show_comment(<<_::288>> = uuid, user) do
    uuid |> get_comment(user) |> Repo.preload([{:user, :profile}])
  end

  @spec show_comment(any) :: nil
  def show_comment(_), do: nil

  @doc """
  Updates a comment
  """
  @spec update_comment(Comment.t(), map) :: Comment.t()
  def update_comment(comment, params) do
    comment
    |> Comment.changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, comment} ->
        comment |> Repo.preload([{:user, :profile}])
    end
  end

  @doc """
  Deletes a coment
  """
  def delete_comment(%Comment{} = comment) do
    comment
    |> Repo.delete()
  end

  @doc """
  Comments under a master
  """
  # TODO - improve tests
  def comment_index(%{organisation_id: org_id}, %{"master_id" => master_id} = params) do
    from(c in Comment,
      where: c.organisation_id == ^org_id,
      where: c.master_id == ^master_id,
      where: c.is_parent == true,
      order_by: [desc: c.inserted_at],
      preload: [{:user, :profile}]
    )
    |> Repo.paginate(params)
  end

  @doc """
   Replies under a comment
  """
  # TODO - improve tests
  @spec comment_replies(%{organisation_id: any}, map) :: Scrivener.Page.t()
  def comment_replies(
        %{organisation_id: org_id} = user,
        %{"master_id" => master_id, "comment_id" => comment_id} = params
      ) do
    with %Comment{id: parent_id} <- get_comment(comment_id, user) do
      from(c in Comment,
        where: c.organisation_id == ^org_id,
        where: c.master_id == ^master_id,
        where: c.is_parent == false,
        where: c.parent_id == ^parent_id,
        order_by: [desc: c.inserted_at],
        preload: [{:user, :profile}]
      )
      |> Repo.paginate(params)
    end
  end

  @doc """
  Create a pipeline.
  """
  @spec create_pipeline(User.t(), map) :: Pipeline.t() | {:error, Ecto.Changeset.t()}
  def create_pipeline(%{organisation_id: org_id} = current_user, params) do
    params = params |> Map.put("organisation_id", org_id)

    current_user
    |> build_assoc(:pipelines)
    |> Pipeline.changeset(params)
    |> Spur.insert()
    |> case do
      {:ok, pipeline} ->
        create_pipe_stages(current_user, pipeline, params)
        pipeline |> Repo.preload(stages: [{:content_type, :fields}, :data_template, :state])

      {:error, _} = changeset ->
        changeset
    end
  end

  # Create pipe stages by iterating over the list of content type UUIDs
  # given among the params.
  @spec create_pipe_stages(User.t(), Pipeline.t(), map) :: list
  defp create_pipe_stages(user, pipeline, %{"stages" => stage_data}) when is_list(stage_data) do
    stage_data
    |> Enum.map(fn stage_params -> create_pipe_stage(user, pipeline, stage_params) end)
  end

  defp create_pipe_stages(_, _, _), do: []

  @doc """
  Create a pipe stage.
  """
  @spec create_pipe_stage(User.t(), Pipeline.t(), map) ::
          nil | {:error, Ecto.Changeset.t()} | {:ok, any}
  def create_pipe_stage(
        user,
        pipeline,
        %{
          "content_type_id" => <<_::288>>,
          "data_template_id" => <<_::288>>,
          "state_id" => <<_::288>>
        } = params
      ) do
    get_pipe_stage_params(params, user) |> do_create_pipe_stages(pipeline)
  end

  def create_pipe_stage(_, _, _), do: nil

  # Get the values for pipe stage creation to create a pipe stage.
  @spec get_pipe_stage_params(map, User.t()) ::
          {ContentType.t(), DataTemplate.t(), State.t(), User.t()}
  defp get_pipe_stage_params(
         %{
           "content_type_id" => c_type_uuid,
           "data_template_id" => d_temp_uuid,
           "state_id" => state_uuid
         },
         user
       ) do
    c_type = get_content_type(user, c_type_uuid)
    d_temp = get_d_template(user, d_temp_uuid)
    state = Enterprise.get_state(user, state_uuid)
    {c_type, d_temp, state, user}
  end

  defp get_pipe_stage_params(_, _), do: nil

  # Create pipe stages
  @spec do_create_pipe_stages(
          {ContentType.t(), DataTemplate.t(), State.t(), User.t()} | nil,
          Pipeline.t()
        ) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_create_pipe_stages(
         {%ContentType{id: c_id}, %DataTemplate{id: d_id}, %State{id: s_id}, %User{id: u_id}},
         pipeline
       ) do
    pipeline
    |> build_assoc(:stages,
      content_type_id: c_id,
      data_template_id: d_id,
      state_id: s_id,
      creator_id: u_id
    )
    |> Stage.changeset()
    |> Repo.insert()
  end

  defp do_create_pipe_stages(_, _), do: nil

  @doc """
  List of all pipelines in the user's organisation.
  """
  @spec pipeline_index(User.t(), map) :: map | nil
  def pipeline_index(%User{organisation_id: org_id}, params) do
    from(p in Pipeline, where: p.organisation_id == ^org_id)
    |> Repo.paginate(params)
  end

  def pipeline_index(_, _), do: nil

  @doc """
  Get a pipeline from its UUID and user's organisation.
  """
  @spec get_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def get_pipeline(%User{organisation_id: org_id}, <<_::288>> = p_uuid) do
    from(p in Pipeline, where: p.uuid == ^p_uuid, where: p.organisation_id == ^org_id)
    |> Repo.one()
  end

  def get_pipeline(_, _), do: nil

  @doc """
  Get a pipeline and its details.
  """
  @spec show_pipeline(User.t(), Ecto.UUID.t()) :: Pipeline.t() | nil
  def show_pipeline(current_user, p_uuid) do
    current_user
    |> get_pipeline(p_uuid)
    |> Repo.preload([:creator, stages: [{:content_type, :fields}, :data_template, :state]])
  end

  @doc """
  Updates a pipeline.
  """
  @spec pipeline_update(Pipeline.t(), User.t(), map) :: Pipeline.t()
  def pipeline_update(%Pipeline{} = pipeline, %User{id: user_id} = user, params) do
    pipeline
    |> Pipeline.update_changeset(params)
    |> Spur.update(%{actor: "#{user_id}"})
    |> case do
      {:ok, pipeline} ->
        user |> create_pipe_stages(pipeline, params)

        pipeline
        |> Repo.preload([:creator, stages: [{:content_type, :fields}, :data_template, :state]])

      {:error, _} = changeset ->
        changeset
    end
  end

  def pipeline_update(_, _, _), do: nil

  @doc """
  Delete a pipeline.
  """
  @spec delete_pipeline(Pipeline.t(), User.t()) ::
          {:ok, Pipeline.t()} | {:error, Ecto.Changeset.t()}
  def delete_pipeline(%Pipeline{} = pipeline, %User{id: id}) do
    pipeline
    |> Spur.delete(%{actor: "#{id}", meta: pipeline})
  end

  def delete_pipeline(_, _), do: nil

  @doc """
  Get a pipeline stage from its UUID and user's organisation.
  """
  @spec get_pipe_stage(User.t(), Ecto.UUID.t()) :: Stage.t() | nil
  def get_pipe_stage(%User{organisation_id: org_id}, <<_::288>> = s_uuid) do
    from(s in Stage,
      join: p in Pipeline,
      where: p.organisation_id == ^org_id and s.pipeline_id == p.id,
      where: s.uuid == ^s_uuid
    )
    |> Repo.one()
  end

  def get_pipe_stage(_, _), do: nil

  @doc """
  Get all required fields and then update a stage.
  """
  @spec update_pipe_stage(User.t(), Stage.t(), map) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  def update_pipe_stage(%User{} = current_user, %Stage{} = stage, %{
        "content_type_id" => c_uuid,
        "data_template_id" => d_uuid,
        "state_id" => s_uuid
      }) do
    c_type = get_content_type(current_user, c_uuid)
    d_temp = get_d_template(current_user, d_uuid)
    state = Enterprise.get_state(current_user, s_uuid)

    do_update_pipe_stage(current_user, stage, c_type, d_temp, state)
  end

  def update_pipe_stage(_, _, _), do: nil

  # Update a stage.
  @spec do_update_pipe_stage(User.t(), Stage.t(), ContentType.t(), DataTemplate.t(), State.t()) ::
          {:ok, Stage.t()} | {:error, Ecto.Changeset.t()} | nil
  defp do_update_pipe_stage(user, stage, %ContentType{id: c_id}, %DataTemplate{id: d_id}, %State{
         id: s_id
       }) do
    stage
    |> Stage.update_changeset(%{content_type_id: c_id, data_template_id: d_id, state_id: s_id})
    |> Spur.update(%{actor: "#{user.id}"})
  end

  defp do_update_pipe_stage(_, _, _, _, _), do: nil

  @doc """
  Delete a pipe stage.
  """
  @spec delete_pipe_stage(User.t(), Stage.t()) :: {:ok, Stage.t()}
  def delete_pipe_stage(%User{id: id}, %Stage{} = pipe_stage) do
    %{pipeline: pipeline, content_type: c_type, data_template: d_temp, state: state} =
      pipe_stage |> Repo.preload([:pipeline, :content_type, :data_template, :state])

    meta = %{pipeline: pipeline, content_type: c_type, data_template: d_temp, state: state}

    pipe_stage |> Spur.delete(%{actor: "#{id}", meta: meta})
  end

  def delete_pipe_stage(_, _), do: nil

  @doc """
  Preload all datas of a pipe stage excluding pipeline.
  """
  @spec preload_stage_details(Stage.t()) :: Stage.t()
  def preload_stage_details(stage) do
    stage |> Repo.preload([{:content_type, :fields}, :data_template, :state])
  end

  @doc """
  Creates a pipeline trigger history with a user association.

  ## Example
  iex> create_trigger_history(%User{}, %Pipeline{}, %{name: "John Doe"})
  {:ok, %TriggerHistory{}}

  iex> create_trigger_history(%User{}, %Pipeline{}, "meta")
  {:error, Ecto.Changeset}

  iex> create_trigger_history("user", "pipeline", "meta")
  nil
  """
  @spec create_trigger_history(User.t(), Pipeline.t(), map) ::
          {:ok, TriggerHistory.t()} | {:error, Ecto.Changeset.t()} | nil
  def create_trigger_history(%User{id: u_id}, %Pipeline{} = pipeline, data) do
    state = TriggerHistory.states()[:enqued]

    pipeline
    |> build_assoc(:trigger_histories, creator_id: u_id)
    |> TriggerHistory.changeset(%{data: data, state: state})
    |> Repo.insert()
  end

  def create_trigger_history(_, _, _), do: nil

  @doc """
  Get all the triggers under a pipeline.
  """
  @spec get_trigger_histories_of_a_pipeline(Pipeline.t(), map) :: map | nil
  def get_trigger_histories_of_a_pipeline(%Pipeline{id: id}, params) do
    from(t in TriggerHistory,
      where: t.pipeline_id == ^id,
      preload: [:creator],
      order_by: [desc: t.inserted_at]
    )
    |> Repo.paginate(params)
  end

  def get_trigger_histories_of_a_pipeline(_, _), do: nil
end

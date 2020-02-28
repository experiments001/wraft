defmodule WraftDoc.Document do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """
  import Ecto
  alias WraftDoc.{Repo, Account.User, Document.Layout, Document.ContentType, Document.Engine}

  @doc """
  Create a layout.
  """
  @spec create_layout(%User{}, map) :: %Layout{} | {:error, Ecto.Changeset.t()}
  def create_layout(current_user, params) do
    current_user
    |> build_assoc(:layouts)
    |> Layout.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, layout} ->
        layout |> Repo.preload(:engine)

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  Create a content type.
  """
  @spec create_content_type(%User{}, map) :: %ContentType{} | {:error, Ecto.Changeset.t()}
  def create_content_type(current_user, params) do
    current_user
    |> build_assoc(:content_types)
    |> ContentType.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, %ContentType{} = content_type} ->
        content_type |> Repo.preload(:layout)

      changeset = {:error, _} ->
        changeset
    end
  end

  @doc """
  List all engines.
  """
  @spec engines_list() :: list
  def engines_list() do
    Repo.all(Engine)
  end

  @doc """
  List all layouts.
  """
  @spec layout_index() :: list
  def layout_index() do
    Repo.all(Layout) |> Repo.preload(:engine)
  end

  @doc """
  Show a layout.
  """
  @spec show_layout(binary) :: %Layout{engine: %Engine{}, creator: %User{}}
  def show_layout(uuid) do
    get_layout(uuid)
    |> Repo.preload([:engine, :creator])
  end

  @doc """
  Get a layout from its UUID.
  """
  @spec get_layout(binary) :: %Layout{}
  def get_layout(uuid) do
    Repo.get_by(Layout, uuid: uuid)
    |> Repo.preload([:engine, :creator])
  end
end

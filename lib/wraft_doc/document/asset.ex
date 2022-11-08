defmodule WraftDoc.Document.Asset do
  @moduledoc """
    The asset model.
  """
  alias __MODULE__
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  schema "asset" do
    field(:name, :string)
    field(:file, WraftDocWeb.AssetUploader.Type)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
  end

  def update_changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast(attrs, [:name])
    |> cast_attachments(attrs, [:file])
    |> validate_required([:name, :file])
  end

  def file_changeset(%Asset{} = asset, attrs \\ %{}) do
    asset
    |> cast_attachments(attrs, [:file])
    |> validate_required([:file])
  end
end

defmodule WraftDoc.Document.Block do
  @moduledoc """
    The block model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias WraftDoc.Document.Block

  schema "block" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:btype, :string)
    field(:dataset, :map)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Block{} = block, attrs \\ %{}) do
    block
    |> cast(attrs, [:name, :btype, :dataset, :creator_id, :organisation_id])
    |> validate_required([:name, :btype, :dataset, :organisation_id])
    |> unique_constraint(:name,
      message: "Block with same name exists.!",
      name: :block_content_type_unique_index
    )
  end
end

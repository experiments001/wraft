defmodule WraftDoc.Document.Block do
  @moduledoc """
    The block model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  alias WraftDoc.Account.User
  import Ecto.Query

  defimpl Spur.Trackable, for: Block do
    def actor(block), do: "#{block.creator_id}"
    def object(block), do: "Block:#{block.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "block" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    field(:btype, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(%Block{} = block, attrs \\ %{}) do
    block
    |> cast(attrs, [:name, :btype, :content_type_id, :organisation_id])
    |> validate_required([:name, :btype, :content_type_id, :organisation_id])
    |> unique_constraint(:name,
      message: "Block with same name exists.!",
      name: :block_content_type_unique_index
    )
  end
end

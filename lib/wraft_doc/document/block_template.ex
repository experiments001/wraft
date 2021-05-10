defmodule WraftDoc.Document.BlockTemplate do
  @moduledoc false
  use WraftDoc.Schema

  alias __MODULE__
  alias WraftDoc.{Account.User}
  import Ecto.Query
  @derive {Jason.Encoder, only: [:title]}
  defimpl Spur.Trackable, for: BlockTemplate do
    def actor(block_template), do: "#{block_template.creator_id}"
    def object(block_template), do: "BlockTemplate:#{block_template.id}"
    def target(_chore), do: nil

    def audience(%{organisation_id: id}) do
      from(u in User, where: u.organisation_id == ^id)
    end
  end

  schema "block_template" do
    field(:title, :string)
    field(:body, :string)
    field(:serialized, :string)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(block_template, attrs \\ %{}) do
    block_template
    |> cast(attrs, [:title, :body, :serialized, :organisation_id])
    |> validate_required([:title, :body, :serialized, :organisation_id])
    |> unique_constraint(:title,
      message: "A block template with the same name exists.!",
      name: :organisation_block_template_unique_index
    )
  end

  def update_changeset(block_template, attrs \\ %{}) do
    block_template
    |> cast(attrs, [:title, :body, :serialized])
    |> validate_required([:title, :body, :serialized])
    |> unique_constraint(:title,
      message: "A block template with the same name exists.!",
      name: :organisation_block_template_unique_index
    )
  end
end

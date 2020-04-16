defmodule WraftDoc.Document.ContentTypeField do
  @moduledoc """
  The content type field model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias __MODULE__
  alias WraftDoc.{Document.ContentType, Account.User}

  defimpl Spur.Trackable, for: ContentTypeField do
    def actor(_content_type_field), do: ""
    def object(content_type_field), do: "ContentTypeField:#{content_type_field.id}"
    def target(_chore), do: nil

    def audience(%{content_type_id: id}) do
      from(u in User,
        join: ct in ContentType,
        where: ct.id == ^id,
        where: u.organisation_id == ct.organisation_id
      )
    end
  end

  schema "content_type_field" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:name, :string, null: false)
    belongs_to(:content_type, WraftDoc.Document.ContentType)
    belongs_to(:field_type, WraftDoc.Document.FieldType)
    timestamps()
  end

  def changeset(field_type, attrs \\ %{}) do
    field_type
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:content_type_id,
      message: "Field type already added.!",
      name: :content_type_field_unique_index
    )
  end
end

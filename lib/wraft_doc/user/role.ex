defmodule WraftDoc.Account.Role do
  @moduledoc """
    This is the Roles module
  """
  use WraftDoc.Schema

  schema "role" do
    field(:name, :string)
    field(:permissions, {:array, :string})
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    has_many(:user_roles, WraftDoc.Account.UserRole)
    has_many(:users, through: [:user_roles, :user])
    has_many(:content_type_roles, WraftDoc.Document.ContentTypeRole)
    has_many(:content_types, through: [:content_type_roles, :content_type])
    timestamps()
  end

  def changeset(role, attrs \\ %{}) do
    role
    |> cast(attrs, [:organisation_id, :name, :permissions])
    |> validate_required([:name, :organisation_id])
    |> unique_constraint(:name,
      name: :organisation_role_unique_index,
      message: "Role exist in this organisation"
    )
  end
end

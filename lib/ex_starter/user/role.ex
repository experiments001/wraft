defmodule ExStarter.UserManagement.Role do
  @moduledoc """
  This is the Roles module
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias ExStarter.UserManagement.Role

  schema "role" do
    field(:name, :string)
    has_many(:users, ExStarter.UserManagement.User)

    timestamps()
  end

  def changeset(%Role{} = role, attrs \\ %{}) do
    role
    |> cast(attrs, [:name, :admin])
    |> validate_required([:name, :admin])
  end
end

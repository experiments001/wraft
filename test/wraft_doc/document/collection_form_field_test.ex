defmodule WraftDoc.Document.CollectionFormFieldTest do
  use WraftDoc.ModelCase

  @moduledoc """
  Test module
  """
  alias WraftDoc.Document.CollectionFormField

  @create_attrs %{name: "asset one"}
  @invalid_attrs %{name: 23}

  test "changeset with valid data" do
    changeset = CollectionFormField.changeset(%CollectionFormField{}, @create_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = CollectionFormField.changeset(%CollectionFormField{}, @invalid_attrs)
    refute changeset.valid?
  end
end

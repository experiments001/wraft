defmodule WraftDoc.DocumentTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  alias WraftDoc.Account
  alias WraftDocWeb.Endpoint

  @valid_attrs %{
    "password" => "Password",
    "name" => "John Doe",
    "email" => "email@xyz.com"
  }

  @email "newemail@xyz.com"

  describe "registration/2" do
    test "user registration with valid data" do
      insert(:role, name: "user")
      organisation = insert(:organisation)
      user = Account.registration(@valid_attrs, organisation)

      assert user.name == @valid_attrs["name"]
      assert user.email == @valid_attrs["email"]
      assert user.profile.name == @valid_attrs["name"]
    end

    test "user registration with invalid data" do
      insert(:role, name: "user")
      organisation = insert(:organisation)
      {:error, changeset} = Account.registration(%{"email" => ""}, organisation)

      assert %{email: ["can't be blank"], name: ["can't be blank"], password: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "user registration with invalid email" do
      insert(:role, name: "user")
      organisation = insert(:organisation)
      params = @valid_attrs |> Map.put("email", "not an email")
      {:error, changeset} = Account.registration(params, organisation)

      assert %{email: ["has invalid format"]} == errors_on(changeset)
    end
  end

  describe "get_organisation_from_token/1" do
    test "verify and accept valid token and email" do
      organisation = insert(:organisation)

      token =
        Phoenix.Token.sign(Endpoint, "organisation_invite", %{
          organisation: organisation,
          email: @email
        })

      org = Account.get_organisation_from_token(%{"token" => token, "email" => @email})
      assert org == organisation
    end

    test "return error for valid token and different email" do
      organisation = insert(:organisation)

      token =
        Phoenix.Token.sign(Endpoint, "organisation_invite", %{
          organisation: organisation,
          email: @email
        })

      error =
        Account.get_organisation_from_token(%{"token" => token, "email" => "anotheremail@xyz.com"})

      assert error == {:error, :no_permission}
    end

    test "return error for valid token but with unexpected encoded data" do
      token =
        Phoenix.Token.sign(
          Endpoint,
          "organisation_invite",
          "expects a map with organisation and email keys, giving a string"
        )

      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return error for invalid token" do
      token = Phoenix.Token.sign(Endpoint, "different salt", "")
      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return error for expired token" do
      organisation = build(:organisation)

      token =
        Phoenix.Token.sign(
          Endpoint,
          "organisation_invite",
          %{organisation: organisation, email: @email},
          signed_at: -9_00_001
        )

      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :expired}
    end

    test "returns not found when params doens't contain token or email or both" do
      resp1 = Account.get_organisation_from_token(%{"token" => nil})
      resp2 = Account.get_organisation_from_token(%{"email" => nil})
      resp3 = Account.get_organisation_from_token(%{})
      assert resp1 == nil
      assert resp2 == nil
      assert resp3 == nil
    end
  end

  describe "create_profile/2" do
    test "create profile for a user with valid attrs" do
      user = insert(:user)
      {:ok, dob} = Date.new(2020, 2, 29)
      params = %{name: user.name, dob: dob, gender: "Male"}
      {:ok, profile} = Account.create_profile(user, params)
      assert profile.name == user.name
      assert profile.dob == dob
      assert profile.gender == "Male"
    end

    test "return error on creating profile for a user with invalid attrs" do
      user = insert(:user)
      {:error, changeset} = Account.create_profile(user, %{})
      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "find/1" do
    test "get user when correct email is provided" do
      user = insert(:user)
      found_user = Account.find(user.email)

      assert user.email == found_user.email
      assert user.id == found_user.id
      assert user.uuid == found_user.uuid
    end

    test "returns error when incorrect email is provided" do
      found_user = Account.find("nouser@xyz.com")
      assert found_user == {:error, :invalid}
    end

    test "return error when invalid data is provided" do
      found_user = Account.find(123)
      assert found_user == {:error, :invalid}
    end
  end

  describe "authenticate/1" do
    test "successfully authenticate when correct password is given" do
      user = insert(:user)
      response = Account.authenticate(%{user: user, password: "encrypt"})
      assert tuple_size(response) == 3
      assert elem(response, 0) == :ok
    end

    test "does not authenticate when nil or empty password is given" do
      user = insert(:user)
      response1 = Account.authenticate(%{user: user, password: ""})
      response2 = Account.authenticate(%{user: user, password: nil})
      assert response1 == {:error, :no_data}
      assert response2 == {:error, :no_data}
    end

    test "does not authenticate when incorrect password is given" do
      user = insert(:user)
      response = Account.authenticate(%{user: user, password: "inorrectpassword"})
      assert response == {:error, :invalid}
    end
  end
end

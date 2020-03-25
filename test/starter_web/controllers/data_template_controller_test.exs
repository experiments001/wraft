defmodule WraftDocWeb.DataTemplateControllerTest do
  @moduledoc """
  Test module for data template controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.DataTemplate, Repo}

  @valid_attrs %{
    tag: "Main template",
    data: "Hi [user]"
  }
  @invalid_attrs %{}
  setup %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  test "create data templates by valid attrrs", %{conn: conn} do
    content_type = insert(:content_type, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    params = Map.put(@valid_attrs, :c_type_id, content_type.uuid)

    count_before = DataTemplate |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_data_template_path(conn, :create, params))
      |> doc(operation_id: "create_data_template")

    assert count_before + 1 == DataTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["tag"] == @valid_attrs.tag
  end

  test "does not create data templates by invalid attrs", %{conn: conn} do
    content_type = insert(:content_type, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = DataTemplate |> Repo.all() |> length()
    params = Map.put(@invalid_attrs, :c_type_id, content_type.uuid)

    conn =
      post(conn, Routes.v1_data_template_path(conn, :create, params))
      |> doc(operation_id: "create_data_template")

    assert json_response(conn, 422)["errors"]["tag"] == ["can't be blank"]
    assert count_before == DataTemplate |> Repo.all() |> length()
  end

  test "update data templates on valid attributes", %{conn: conn} do
    data_template = insert(:data_template, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = DataTemplate |> Repo.all() |> length()

    conn =
      put(conn, Routes.v1_data_template_path(conn, :update, data_template.uuid, @valid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 200)["data_template"]["tag"] == @valid_attrs.tag
    assert count_before == DataTemplate |> Repo.all() |> length()
  end

  test "does't update data templates for invalid attrs", %{conn: conn} do
    data_template = insert(:data_template, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_data_template_path(conn, :update, data_template.uuid, @invalid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 422)["errors"]["file"] == ["can't be blank"]
  end

  test "index lists all data templates under a content type", %{conn: conn} do
    user = conn.assigns.current_user
    content_type = insert(:content_type)

    dt1 = insert(:data_template, creator: user, content_type: content_type)
    dt2 = insert(:data_template, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_data_template_path(conn, :index, content_type.uuid))
    dt_index = json_response(conn, 200)["data_templates"]
    data_templates = Enum.map(dt_index, fn %{"tag" => tag} -> tag end)
    assert List.to_string(data_templates) =~ dt1.tag
    assert List.to_string(data_templates) =~ dt2.tag
  end

  test "all templates lists all data templates under an organisation", %{conn: conn} do
    user = conn.assigns.current_user
    content_type = insert(:content_type)

    dt1 = insert(:data_template, creator: user, content_type: content_type)
    dt2 = insert(:data_template, creator: user, content_type: content_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_data_template_path(conn, :all_templates))
    dt_index = json_response(conn, 200)["data_templates"]
    data_templates = Enum.map(dt_index, fn %{"tag" => tag} -> tag end)
    assert List.to_string(data_templates) =~ dt1.tag
    assert List.to_string(data_templates) =~ dt2.tag
  end

  test "show renders asset details by id", %{conn: conn} do
    data_template = insert(:data_template, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_data_template_path(conn, :show, data_template.uuid))

    assert json_response(conn, 200)["data_template"]["tag"] == data_template.tag
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_data_template_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete asset by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    data_template = insert(:data_template, creator: conn.assigns.current_user)
    count_before = DataTemplate |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_data_template_path(conn, :delete, data_template.uuid))
    assert count_before - 1 == DataTemplate |> Repo.all() |> length()
    assert json_response(conn, 200)["tag"] == data_template.tag
  end
end

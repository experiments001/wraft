defmodule WraftDocWeb.Api.V1.InstanceController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{
    Document,
    Document.Instance,
    Document.ContentType,
    Enterprise,
    Enterprise.Flow.State
  }

  def swagger_definitions do
    %{
      Content:
        swagger_schema do
          title("Content")
          description("A content, which is then used to generate the out files.")

          properties do
            id(:string, "The ID of the content", required: true)
            instance_id(:string, "A unique ID generated for the content")
            raw(:string, "Raw data of the content")
            serialized(:map, "Serialized data of the content")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            instance_id: "OFFL01",
            raw: "Content",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentRequest:
        swagger_schema do
          title("Content Request")
          description("Content creation request")

          properties do
            raw(:string, "Content raw data", required: true)
            serialized(:string, "Content serialized data")
            state_uuid(:string, "state id", required: true)
          end

          example(%{
            raw: "Content data",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            state_uuid: "kjb12389k23eyg"
          })
        end,
      ContentAndContentTypeAndState:
        swagger_schema do
          title("Content and its Content Type")
          description("A content and its content type")

          properties do
            content(Schema.ref(:Content))
            content_type(Schema.ref(:ContentType))
            state(Schema.ref(:State))
          end

          example(%{
            content: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              fields: %{
                name: "string",
                position: "string",
                joining_date: "date",
                approved_by: "string"
              },
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            state: %{
              id: "1232148nb3478",
              state: "published",
              order: 1,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ShowContent:
        swagger_schema do
          title("Content and its details")
          description("A content and all its details")

          properties do
            content(Schema.ref(:Content))
            content_type(Schema.ref(:ContentType))
            state(Schema.ref(:State))
            creator(Schema.ref(:User))
          end

          example(%{
            content: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              fields: %{
                name: "string",
                position: "string",
                joining_date: "date",
                approved_by: "string"
              },
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            state: %{
              id: "1232148nb3478",
              state: "published",
              order: 1,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ContentsAndContentTypeAndState:
        swagger_schema do
          title("Instances, their content types and states")
          description("IInstances and all its details except creator.")
          type(:array)
          items(Schema.ref(:ContentAndContentTypeAndState))
        end,
      ContentsIndex:
        swagger_schema do
          properties do
            contents(Schema.ref(ContentsAndContentTypeAndState))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            contents: [
              %{
                content: %{
                  id: "1232148nb3478",
                  instance_id: "OFFL01",
                  raw: "Content",
                  serialized: %{title: "Title of the content", body: "Body of the content"},
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                content_type: %{
                  id: "1232148nb3478",
                  name: "Offer letter",
                  description: "An offer letter",
                  fields: %{
                    name: "string",
                    position: "string",
                    joining_date: "date",
                    approved_by: "string"
                  },
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                state: %{
                  id: "1232148nb3478",
                  state: "published",
                  order: 1,
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                }
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end
    }
  end

  @doc """
  Create an instance.
  """
  swagger_path :create do
    post("/content_types/{c_type_id}/contents")
    summary("Create a content")
    description("Create content API")

    parameters do
      c_type_id(:path, :string, "content type id", required: true)
      content(:body, Schema.ref(:ContentRequest), "Content to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentAndContentTypeAndState))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"c_type_id" => c_type_uuid, "state_uuid" => state_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = c_type <- Document.get_content_type(c_type_uuid),
         %State{} = state <- Enterprise.get_state(state_uuid),
         %Instance{} = content <- Document.create_instance(current_user, c_type, state, params) do
      conn
      |> render(:create, content: content)
    end
  end

  @doc """
  Instance index.
  """
  swagger_path :index do
    get("/content_types/{c_type_id}/contents")
    summary("Instance index")
    description("API to get the list of all instances created so far under a content type")

    parameters do
      c_type_id(:path, :string, "ID of the content type", required: true)
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:ContentsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"c_type_id" => c_type_uuid} = params) do
    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_index(c_type_uuid, params) do
      conn
      |> render("index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  All instances.
  """
  swagger_path :all_contents do
    get("/contents")
    summary("All instances")
    description("API to get the list of all instances created so far under an organisation")

    parameters do
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:ContentsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec all_contents(Plug.Conn.t(), map) :: Plug.Conn.t()
  def all_contents(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: contents,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.instance_index_of_an_organisation(current_user, params) do
      conn
      |> render("index.json",
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show instance.
  """
  swagger_path :show do
    get("/contents/{id}")
    summary("Show an instance")
    description("API to get all details of an instance")

    parameters do
      id(:path, :string, "ID of the instance", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => instance_uuid}) do
    with %Instance{} = instance <- Document.show_instance(instance_uuid) do
      conn
      |> render("show.json", instance: instance)
    end
  end

  @doc """
  Update an instance.
  """
  swagger_path :update do
    put("/contents/{id}")
    summary("Update an instance")
    description("API to update an instance")

    parameters do
      id(:path, :string, "Instance id", required: true)

      content(:body, Schema.ref(:ContentRequest), "Instance to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContent))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %Instance{} = instance <- Document.get_instance(uuid),
         %Instance{} = instance <- Document.update_instance(instance, params) do
      conn
      |> render("show.json", instance: instance)
    end
  end

  @doc """
  Delete an instance.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/contents/{id}")
    summary("Delete an instance")
    description("API to delete an instance")

    parameters do
      id(:path, :string, "instance id", required: true)
    end

    response(200, "Ok", Schema.ref(:Content))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %Instance{} = instance <- Document.get_instance(uuid),
         {:ok, %Instance{}} <- Document.delete_instance(instance) do
      conn
      |> render("instance.json", instance: instance)
    end
  end
end

defmodule WraftDocWeb.Api.V1.FlowController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Enterprise.Flow}

  def swagger_definitions do
    %{
      FlowRequest:
        swagger_schema do
          title("Flow Request")
          description("Create flow request.")

          properties do
            state(:string, "State name", required: true)
            order(:integer, "State's order", required: true)
          end

          example(%{
            state: "Published",
            order: 1
          })
        end,
      Flow:
        swagger_schema do
          title("Flow")
          description("State assigened to contents")

          properties do
            id(:string, "ID of the flow")
            state(:string, "A state of content")
            order(:integer, "Order of the state")
          end

          example(%{
            id: "1232148nb3478",
            state: "published",
            order: 1
          })
        end,
      ShowFlow:
        swagger_schema do
          title("Show flow details")
          description("Show all details of a flow")

          properties do
            flow(Schema.ref(:Flow))
            creator(Schema.ref(:User))
          end

          example(%{
            flow: %{
              id: "1232148nb3478",
              state: "published",
              order: 1
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
        end
    }
  end

  @doc """
  Create a flow.
  """
  swagger_path :create do
    post("/flows")
    summary("Create a flow")
    description("Create flow API")

    parameters do
      flow(:body, Schema.ref(:FlowRequest), "Flow to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Flow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Document.create_flow(current_user, params) do
      conn |> render("flow.json", flow: flow)
    end
  end
end

defmodule WraftDocWeb.Api.V1.PipeStageController do
  @moduledoc """
  PipeStageController module handles all the actions associated with
  Pipe stage model.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{Document, Document.Pipeline, Document.Pipeline.Stage}

  def swagger_definitions do
    %{
      PipeStageRequestMap:
        swagger_schema do
          title("Pipe stage request")
          description("Map with content type, data template and state UUIDs")

          properties do
            content_type_id(:string, "Content type UUID")
            data_template_id(:string, "Data template UUID")
            state_id(:string, "State UUID")
          end

          example(%{
            content_type_id: "1232148nb3478",
            data_template_id: "1232148nb3478",
            state_id: "1232148nb3478"
          })
        end,
      PipeStage:
        swagger_schema do
          title("Pipeline stage")
          description("One stage in a pipeline.")

          properties do
            content_type(Schema.ref(:ContentTypeWithoutFields))
            data_template(Schema.ref(:DataTemplate))
            state(Schema.ref(:State))
          end
        end,
      PipeStages:
        swagger_schema do
          title("Pipe stages list")
          description("List of pipe stages")
          type(:array)
          items(Schema.ref(:PipeStage))
        end
    }
  end

  @doc """
  Creates a pipe stage.
  """
  swagger_path :create do
    post("/pipelines/{pipeline_id}/stages")
    summary("Create a pipe stage")
    description("Create pipe stage API")

    parameters do
      pipeline_id(:path, :string, "ID of the pipeline", required: true)

      pipeline(:body, Schema.ref(:PipeStageRequestMap), "Pipe stage to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:PipelineAndStages))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"pipeline_id" => p_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Pipeline{} = pipeline <- Document.get_pipeline(current_user, p_uuid),
         {:ok, %Stage{} = stage} <- Document.create_pipe_stage(current_user, pipeline, params),
         %Stage{} = stage <- Document.preload_stage_details(stage) do
      conn |> render("stage.json", stage: stage)
    end
  end

  @doc """
  Updates a pipe stage.
  """
  swagger_path :update do
    put("/stages/{id}")
    summary("Update a pipe stage")
    description("Update pipe stage API")

    parameters do
      id(:path, :string, "ID of the pipe stage", required: true)
      stage(:body, Schema.ref(:PipeStageRequestMap), "Pipe stage to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:PipeStage))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => s_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Stage{} = stage <- Document.get_pipe_stage(current_user, s_uuid),
         {:ok, %Stage{} = stage} <- Document.update_pipe_stage(current_user, stage, params),
         %Stage{} = stage <- Document.preload_stage_details(stage) do
      conn |> render("stage.json", stage: stage)
    end
  end
end

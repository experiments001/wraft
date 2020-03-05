defmodule WraftDocWeb.Api.V1.DataTemplateView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{ContentTypeView, UserView}

  def render("create.json", %{d_template: d_temp}) do
    %{
      id: d_temp.uuid,
      tag: d_temp.tag,
      data: d_temp.data,
      inserted_at: d_temp.inserted_at,
      updated_at: d_temp.updated_at
    }
  end

  def render("index.json", %{data_templates: data_templates}) do
    render_many(data_templates, DataTemplateView, "create.json", as: :d_template)
  end

  def render("show.json", %{d_template: d_temp}) do
    %{
      data_template: render_one(d_temp, DataTemplateView, "create.json", as: :d_template),
      content_type:
        render_one(d_temp.content_type, ContentTypeView, "content_type.json", as: :content_type),
      creator: render_one(d_temp.creator, UserView, "user.json", as: :user)
    }
  end
end

defmodule WraftDocWeb.Mailer.Email do
  @moduledoc false

  import Bamboo.Email

  def invite_email(org_name, user_name, email, token) do
    base_email()
    |> to(email)
    |> subject("Invitation to join #{org_name} in WraftDocs")
    |> html_body(
      "Hi, #{user_name} has invited you to join #{org_name} in WraftDocs. \n
    Click <a href=#{WraftDocWeb.Endpoint.url()}/users/signup?token=#{token}>here</a> below to join."
    )
  end

  def notification_email(notification, user) do
    base_email()
    |> to(user.email)
    |> subject(" #{user.name} ")
    |> html_body(
      "Hi, #{user.name} #{WraftDoc.Notifications.get_notification_message(notification)}"
    )
  end

  defp base_email do
    from(new_email(), {"WraftDoc", "admin@wraftdocs.com"})
  end

  @doc """
  Password reset link.
  """

  def password_reset(token) do
    new_email()
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> to(token.user.email)
    |> subject("Forgot your WraftDoc Password?")
    |> html_body(
      "Hi #{token.user.name}.\n You recently requested to reset your password for WraftDocs
    Click <a href=#{WraftDocWeb.Endpoint.url()}/users/password/reset?token=#{token.value}>here</a> to reset"
    )
  end
end

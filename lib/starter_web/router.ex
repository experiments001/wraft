defmodule ExStarterWeb.Router do
  use ExStarterWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(ExStarterWeb.Guardian.AuthPipeline)
  end

  scope "/", ExStarterWeb do
    # Use the default browser stack
    pipe_through(:api)
    get("/", PageController, :index)
  end

  # Scope which does not need authorization.
  scope "/api", ExStarterWeb do
    pipe_through(:api)

    # user
    scope "/v1", Api.V1, as: :v1 do
      post("/users/", RegistrationController, :create)
      post("/users/login", UserController, :signin)
    end
  end

  # Scope which requires authorization.
  scope "/api", ExStarterWeb do
    pipe_through([:api, :api_auth])

    scope "/v1", Api.V1, as: :v1 do
      post("/user/profile/", ProfileController, :update)
    end
  end
end

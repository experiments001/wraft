defmodule WraftDoc.Mixfile do
  use Mix.Project

  def project do
    [
      app: :wraft_doc,
      version: "0.0.1",
      elixir: "~> 1.10.2",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:phoenix_swagger],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {WraftDoc.Application, []},
      extra_applications: [:logger, :runtime_tools, :arc_ecto]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.14", override: true},
      {:phoenix_pubsub, "~> 1.1.2"},
      {:phoenix_ecto, "~> 4.1.0"},
      {:ecto_sql, "~> 3.3.4"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.14.1"},
      {:phoenix_live_reload, "~> 1.2.1", only: :dev},
      {:gettext, "~> 0.17.4"},
      {:plug_cowboy, "~> 2.1.2"},
      {:distillery, "~> 2.1.1"},
      # Password encryption
      {:comeonin, "~> 5.1.3"},
      {:bcrypt_elixir, "~> 2.0.3"},
      # User authentication
      {:guardian, "~> 2.0.0"},
      # CORS
      {:cors_plug, "~> 2.0.2"},
      # File upload to AWS
      {:arc, "~> 0.11.0"},
      {:arc_ecto, "~> 0.11.3"},
      # Time and date formating
      {:timex, "~>  3.6.1"},
      # JSON parser
      {:jason, "~> 1.1"},
      {:poison, "~> 3.0", override: true},
      # API documentation
      {:phoenix_swagger, "~> 0.8.2"},

      # For Writing Api documentation by slate
      {:bureaucrat, "~> 0.2.5"},
      {:ex_json_schema, "~> 0.5"},
      # For testing
      {:ex_machina, "~> 2.3", only: :test},
      {:bypass, "~> 1.0", only: :test},
      # Pagination
      {:scrivener_ecto, "~> 2.3"},
      # QR code generation
      {:eqrcode, "~> 0.1.7"},
      # Background jobs
      {:oban, "~> 1.2"},
      # Email client
      {:bamboo, "~> 1.4"},
      {:httpoison, "~> 1.6"},

      # Activity stream
      {:spur, git: "https://github.com/shijithkjayan/spur.git"},
      # CSV parser
      {:csv, "~> 2.3.1"},
      # Live dashboard
      {:phoenix_live_dashboard, "~> 0.1.0"},
      # Business logic flow
      {:opus, "~> 0.6.1"},
      # Razorpay
      {:razorpay, "~> 0.5.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test --trace"],
      swagger: ["phx.swagger.generate priv/static/swagger.json"]
    ]
  end
end

defmodule MayorGame.MixProject do
  use Mix.Project

  # this is kinda like package.json lol

  def project do
    [
      app: :mayor_game,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  # mod here specifies a module to invoke when the application is started
  def application do
    [
      mod: {MayorGame.Application, []},
      extra_applications: [:logger, :runtime_tools]
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
      {:phoenix, "~> 1.7.21"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.19"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:phoenix_live_view, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.3"},
      {:pow, "~> 1.0.39"},
      {:plug_cowboy, "~> 2.7"},
      {:accessible, "~> 0.3.0"},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.1", runtime: Mix.env() == :dev},
      {:hackney, "~> 1.9"},
      {:swoosh, "~> 1.9"},
      {:pow_postgres_store, "~> 1.0"},
      {:number, "~> 1.0"},
      {:statistics, "~> 0.6.3"},
      {:ecto_commons, "~> 0.3.7"},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        # "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "tailwind default --minify",
        "phx.digest"
      ]
    ]
  end
end

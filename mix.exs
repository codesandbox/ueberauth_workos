defmodule UeberauthWorkos.MixProject do
  use Mix.Project

  @version "0.0.1-rc.0"
  @source_url "https://github.com/codesandbox/ueberauth_workos"

  def project do
    [
      app: :ueberauth_workos,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      name: "Ueberauth Strategy for WorkOS",
      source_url: @source_url,
      homepage_url: @source_url,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:jason, "~> 1.0", optional: true},
      {:mock, "~> 0.3.0", only: :test},
      {:oauth2, "~> 2.0"},
      {:ueberauth, "~> 0.10"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md": [title: "Overview"],
        "guides/getting-started.md": [title: "Getting Started"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"],
        "CONTRIBUTING.md": [title: "Contributing"],
        LICENSE: [title: "License"]
      ]
    ]
  end

  defp package do
    [
      description: "Ueberauth Strategy for WorkOS Single Sign-On",
      files: [
        "guides",
        "lib",
        "LICENSE",
        "mix.exs",
        "README.md"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["AJ Foster"]
    ]
  end
end

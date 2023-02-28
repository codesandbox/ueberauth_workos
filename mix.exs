defmodule UeberauthWorkos.MixProject do
  use Mix.Project

  def project do
    [
      app: :ueberauth_workos,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ueberauth, "~> 0.10"}
    ]
  end
end

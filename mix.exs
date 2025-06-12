defmodule ElixirLeanLab.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_lean_lab,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Minimal VM builder for Elixir applications",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ElixirLeanLab.Application, []}
    ]
  end

  defp deps do
    [
      # JSON handling
      {:jason, "~> 1.4"},
      
      # Documentation
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      
      # Testing
      {:stream_data, "~> 0.6", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/somebloke1/elixir-lean-lab"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "docs/ARCHITECTURE.md"]
    ]
  end
end
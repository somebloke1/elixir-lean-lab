defmodule ElixirLeanLab.Builder.Nerves do
  @moduledoc """
  Nerves-based minimal VM builder.
  
  Leverages the Nerves Project for embedded Elixir systems:
  - Pre-built minimal Linux systems
  - Hardware-specific targets
  - Firmware packaging
  - OTA update support
  """

  alias ElixirLeanLab.{Builder, Config}

  def build(%Config{} = config) do
    {:error, "Nerves builder not yet implemented. Use :alpine for now."}
  end
end
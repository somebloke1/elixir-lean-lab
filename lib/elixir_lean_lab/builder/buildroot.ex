defmodule ElixirLeanLab.Builder.Buildroot do
  @moduledoc """
  Buildroot-based minimal VM builder.
  
  Uses Buildroot to create custom Linux systems with:
  - Custom kernel configuration
  - Minimal root filesystem
  - musl or uClibc for small size
  - Direct hardware support
  """

  alias ElixirLeanLab.{Builder, Config}

  def build(%Config{} = config) do
    {:error, "Buildroot builder not yet implemented. Use :alpine for now."}
  end
end
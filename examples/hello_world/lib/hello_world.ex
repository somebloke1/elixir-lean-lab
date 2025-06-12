defmodule HelloWorld do
  @moduledoc """
  A minimal Hello World application for testing VM builds.
  """

  def hello do
    IO.puts("Hello from minimal Elixir VM!")
    IO.puts("VM size optimized with Elixir Lean Lab")
    IO.puts("Memory usage: #{:erlang.memory(:total) |> format_bytes()}")
  end

  defp format_bytes(bytes) do
    mb = bytes / 1_048_576
    "#{Float.round(mb, 2)} MB"
  end
end
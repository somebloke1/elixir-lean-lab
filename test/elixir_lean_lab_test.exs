defmodule ElixirLeanLabTest do
  use ExUnit.Case
  doctest ElixirLeanLab

  test "greets the world" do
    assert ElixirLeanLab.hello() == :world
  end

  test "returns version" do
    assert ElixirLeanLab.version() == "0.1.0"
  end
end
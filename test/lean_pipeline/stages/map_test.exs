defmodule LeanPipeline.Stages.MapTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias LeanPipeline.Stages.Map
  
  describe "process/2" do
    test "applies transformation to each element" do
      stream = Stream.iterate(1, &(&1 + 1)) |> Stream.take(5)
      result = Map.process(stream, transform: &(&1 * 2)) |> Enum.to_list()
      
      assert result == [2, 4, 6, 8, 10]
    end
    
    test "handles empty stream" do
      result = Map.process([], transform: &(&1 * 2)) |> Enum.to_list()
      assert result == []
    end
    
    test "preserves stream laziness" do
      # Should not evaluate until consumed
      stream = Stream.iterate(1, fn _ -> raise "Should not evaluate" end)
      mapped = Map.process(stream, transform: &(&1 * 2))
      
      # Taking only first element should not trigger the error
      assert [2] = mapped |> Enum.take(1)
    end
    
    test "raises on missing transform option" do
      assert_raise KeyError, ~r/key :transform not found/, fn ->
        Map.process([1, 2, 3], [])
      end
    end
    
    test "raises on invalid transform function" do
      assert_raise ArgumentError, ~r/transform must be a function of arity 1/, fn ->
        Map.process([1, 2, 3], transform: "not a function")
      end
    end
    
    test "propagates errors from transform function" do
      assert_raise ArithmeticError, fn ->
        [1, 0, 3]
        |> Map.process(transform: fn x -> 10 / x end)
        |> Enum.to_list()
      end
    end
  end
  
  describe "describe/0" do
    test "returns stage description" do
      assert Map.describe() == "Map"
    end
  end
  
  # Property-based tests
  property "map preserves order" do
    check all list <- list_of(integer(), min_length: 1, max_length: 100) do
      transform = &(&1 + 1)
      
      result = list
      |> Map.process(transform: transform)
      |> Enum.to_list()
      
      expected = Enum.map(list, transform)
      assert result == expected
    end
  end
  
  property "identity function returns unchanged stream" do
    check all list <- list_of(term(), min_length: 0, max_length: 100) do
      result = list
      |> Map.process(transform: & &1)
      |> Enum.to_list()
      
      assert result == list
    end
  end
end
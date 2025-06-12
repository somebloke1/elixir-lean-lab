defmodule LeanPipeline.Stages.WindowTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias LeanPipeline.Stages.Window
  
  describe "tumbling windows" do
    test "count-based tumbling window" do
      result = 1..10
      |> Window.process(type: :tumbling, size: 3)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]
    end
    
    test "handles exact multiples" do
      result = 1..6
      |> Window.process(type: :tumbling, size: 2)
      |> Enum.to_list()
      
      assert result == [[1, 2], [3, 4], [5, 6]]
    end
    
    test "handles empty stream" do
      result = []
      |> Window.process(type: :tumbling, size: 5)
      |> Enum.to_list()
      
      assert result == []
    end
    
    test "single element window" do
      result = 1..5
      |> Window.process(type: :tumbling, size: 1)
      |> Enum.to_list()
      
      assert result == [[1], [2], [3], [4], [5]]
    end
    
    test "time-based tumbling window" do
      stream = Stream.unfold(1, fn
        n when n <= 5 ->
          Process.sleep(10)
          {n, n + 1}
        _ ->
          nil
      end)
      
      result = stream
      |> Window.process(type: :tumbling, duration: 25)
      |> Enum.to_list()
      
      # Should create multiple windows based on timing
      assert length(result) >= 2
      assert List.flatten(result) == [1, 2, 3, 4, 5]
    end
  end
  
  describe "sliding windows" do
    test "sliding window with slide equal to size" do
      result = 1..6
      |> Window.process(type: :sliding, size: 2, slide: 2)
      |> Enum.to_list()
      
      # Same as tumbling when slide equals size
      assert result == [[1, 2], [3, 4], [5, 6]]
    end
    
    test "overlapping sliding window" do
      result = 1..5
      |> Window.process(type: :sliding, size: 3, slide: 1)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
    end
    
    test "sliding window with larger slide" do
      result = 1..10
      |> Window.process(type: :sliding, size: 3, slide: 2)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [3, 4, 5], [5, 6, 7], [7, 8, 9], [9, 10]]
    end
    
    test "rejects slide larger than window size" do
      assert_raise ArgumentError, ~r/Slide interval cannot be larger than window size/, fn ->
        Window.process([1, 2, 3], type: :sliding, size: 2, slide: 3)
      end
    end
  end
  
  describe "error cases" do
    test "raises on unknown window type" do
      assert_raise ArgumentError, ~r/Unknown window type: :invalid/, fn ->
        Window.process([1, 2, 3], type: :invalid)
      end
    end
    
    test "raises when missing size and duration" do
      assert_raise ArgumentError, ~r/Window requires either :size or :duration/, fn ->
        Window.process([1, 2, 3], type: :tumbling)
      end
    end
    
    test "raises when sliding window missing size" do
      assert_raise KeyError, fn ->
        Window.process([1, 2, 3], type: :sliding)
      end
    end
  end
  
  describe "describe/0" do
    test "returns stage description" do
      assert Window.describe() == "Window"
    end
  end
  
  # Property-based tests
  property "tumbling windows partition all elements exactly once" do
    check all list <- list_of(integer(), min_length: 0, max_length: 100),
              size <- positive_integer() do
      
      windows = list
      |> Window.process(type: :tumbling, size: size)
      |> Enum.to_list()
      
      flattened = List.flatten(windows)
      
      # All elements are preserved
      assert flattened == list
      
      # No window exceeds the size (except possibly the last)
      assert Enum.all?(Enum.drop(windows, -1), &(length(&1) == size))
      
      # Last window is partial if list length not divisible by size
      if length(list) > 0 and rem(length(list), size) != 0 do
        assert length(List.last(windows)) == rem(length(list), size)
      end
    end
  end
  
  property "sliding windows maintain size constraint" do
    check all list <- list_of(integer(), min_length: 5, max_length: 50),
              size <- integer(2..10),
              slide <- integer(1..10) do
      
      # Skip invalid combinations
      if slide <= size do
        windows = list
        |> Window.process(type: :sliding, size: size, slide: slide)
        |> Enum.to_list()
        
        # All windows have the correct size (except possibly the last)
        assert Enum.all?(Enum.drop(windows, -1), &(length(&1) == size))
      end
    end
  end
end
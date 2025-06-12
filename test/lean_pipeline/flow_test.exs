defmodule LeanPipeline.FlowTest do
  use ExUnit.Case, async: true
  
  alias LeanPipeline.Flow
  
  describe "create/2" do
    test "creates stream from list" do
      result = Flow.create([1, 2, 3]) |> Enum.to_list()
      assert result == [1, 2, 3]
    end
    
    test "creates stream from range" do
      result = Flow.create(1..5) |> Enum.to_list()
      assert result == [1, 2, 3, 4, 5]
    end
    
    test "handles empty enumerable" do
      result = Flow.create([]) |> Enum.to_list()
      assert result == []
    end
  end
  
  describe "with_backpressure/2" do
    test "processes elements with backpressure" do
      result = 1..10
      |> Flow.create()
      |> Flow.with_backpressure(3)
      |> Enum.to_list()
      
      assert result == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end
    
    test "handles empty stream" do
      result = []
      |> Flow.create()
      |> Flow.with_backpressure(5)
      |> Enum.to_list()
      
      assert result == []
    end
  end
  
  describe "parallel/3" do
    test "applies transformation in parallel" do
      result = 1..10
      |> Flow.create()
      |> Flow.parallel(&(&1 * 2), 4)
      |> Enum.to_list()
      
      assert result == [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
    end
    
    test "handles expensive operations efficiently" do
      start_time = System.monotonic_time(:millisecond)
      
      result = 1..8
      |> Flow.create()
      |> Flow.parallel(fn x ->
        # Simulate expensive operation
        Process.sleep(50)
        x * 2
      end, 4)
      |> Enum.to_list()
      
      duration = System.monotonic_time(:millisecond) - start_time
      
      # With parallelism of 4, should take ~100ms (2 batches)
      # not ~400ms (sequential)
      assert duration < 200
      assert result == [2, 4, 6, 8, 10, 12, 14, 16]
    end
  end
  
  describe "batch/3" do
    test "batches by size" do
      result = 1..10
      |> Flow.create()
      |> Flow.batch(3)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]
    end
    
    test "batches by timeout" do
      stream = Stream.unfold(1, fn
        n when n <= 5 ->
          Process.sleep(20)
          {n, n + 1}
        _ ->
          nil
      end)
      
      result = stream
      |> Flow.create()
      |> Flow.batch(10, 50)  # batch size 10, timeout 50ms
      |> Enum.to_list()
      
      # Should create multiple batches due to timeout
      assert length(result) > 1
      assert List.flatten(result) == [1, 2, 3, 4, 5]
    end
    
    test "handles empty stream" do
      result = []
      |> Flow.create()
      |> Flow.batch(5)
      |> Enum.to_list()
      
      assert result == []
    end
    
    test "flushes final partial batch" do
      result = 1..7
      |> Flow.create()
      |> Flow.batch(3)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [4, 5, 6], [7]]
    end
  end
end
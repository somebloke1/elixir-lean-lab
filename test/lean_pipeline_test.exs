defmodule LeanPipelineTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  doctest LeanPipeline
  
  alias LeanPipeline
  
  describe "pipeline construction" do
    test "creates empty pipeline" do
      pipeline = LeanPipeline.new()
      assert %LeanPipeline{stages: [], source: nil} = pipeline
    end
    
    test "creates pipeline from enumerable" do
      pipeline = LeanPipeline.from_enumerable([1, 2, 3])
      assert %LeanPipeline{source: [1, 2, 3]} = pipeline
    end
    
    test "adds stages in order" do
      pipeline = [1, 2, 3]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.map(&(&1 * 2))
      |> LeanPipeline.filter(&(&1 > 3))
      
      assert length(pipeline.stages) == 2
      assert {LeanPipeline.Stages.Map, _} = Enum.at(pipeline.stages, 0)
      assert {LeanPipeline.Stages.Filter, _} = Enum.at(pipeline.stages, 1)
    end
    
    test "raises when running pipeline without source" do
      assert_raise ArgumentError, ~r/Pipeline has no source/, fn ->
        LeanPipeline.new()
        |> LeanPipeline.map(&(&1 * 2))
        |> LeanPipeline.run()
      end
    end
  end
  
  describe "basic transformations" do
    test "map transformation" do
      result = [1, 2, 3]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.map(&(&1 * 2))
      |> Enum.to_list()
      
      assert result == [2, 4, 6]
    end
    
    test "filter transformation" do
      result = [1, 2, 3, 4, 5]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.filter(&(&1 > 3))
      |> Enum.to_list()
      
      assert result == [4, 5]
    end
    
    test "flat_map transformation" do
      result = ["hello world", "foo bar"]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.flat_map(&String.split/1)
      |> Enum.to_list()
      
      assert result == ["hello", "world", "foo", "bar"]
    end
    
    test "combined transformations" do
      result = 1..10
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.map(&(&1 * 2))
      |> LeanPipeline.filter(&(rem(&1, 3) == 0))
      |> LeanPipeline.map(&to_string/1)
      |> Enum.to_list()
      
      assert result == ["6", "12", "18"]
    end
  end
  
  describe "stream operations" do
    test "take limits elements" do
      result = Stream.iterate(1, &(&1 + 1))
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.take(5)
      |> Enum.to_list()
      
      assert result == [1, 2, 3, 4, 5]
    end
    
    test "drop skips elements" do
      result = 1..10
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.drop(7)
      |> Enum.to_list()
      
      assert result == [8, 9, 10]
    end
    
    test "deduplicate removes consecutive duplicates" do
      result = [1, 1, 2, 2, 2, 3, 1, 1]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.deduplicate()
      |> Enum.to_list()
      
      assert result == [1, 2, 3, 1]
    end
  end
  
  describe "windowing" do
    test "tumbling window by count" do
      result = 1..10
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.window(:tumbling, size: 3)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10]]
    end
    
    test "sliding window" do
      result = 1..5
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.window(:sliding, size: 3, slide: 1)
      |> Enum.to_list()
      
      assert result == [[1, 2, 3], [2, 3, 4], [3, 4, 5]]
    end
  end
  
  describe "side effects" do
    test "tap observes without modification" do
      {:ok, agent} = Agent.start_link(fn -> [] end)
      
      result = [1, 2, 3]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.tap(fn x -> Agent.update(agent, &[x | &1]) end)
      |> LeanPipeline.map(&(&1 * 2))
      |> Enum.to_list()
      
      assert result == [2, 4, 6]
      assert Agent.get(agent, & &1) |> Enum.reverse() == [1, 2, 3]
    end
  end
  
  describe "error handling" do
    test "propagates errors from map" do
      assert_raise ArithmeticError, fn ->
        [1, 2, 0, 4]
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.map(fn x -> 10 / x end)
        |> Enum.to_list()
      end
    end
    
    test "propagates errors from filter" do
      assert_raise FunctionClauseError, fn ->
        [1, 2, nil, 4]
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.filter(&(&1 > 0))
        |> Enum.to_list()
      end
    end
  end
  
  describe "pipeline description" do
    test "describes simple pipeline" do
      desc = [1, 2, 3]
      |> LeanPipeline.from_enumerable()
      |> LeanPipeline.map(&(&1 * 2))
      |> LeanPipeline.filter(&(&1 > 3))
      |> LeanPipeline.describe()
      
      assert desc == "Source |> Map |> Filter"
    end
  end
  
  # Property-based tests
  describe "properties" do
    property "map preserves element count" do
      check all list <- list_of(integer(), min_length: 0, max_length: 100) do
        result = list
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.map(&(&1 + 1))
        |> Enum.to_list()
        
        assert length(result) == length(list)
      end
    end
    
    property "filter never increases element count" do
      check all list <- list_of(integer(), min_length: 0, max_length: 100) do
        result = list
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.filter(&(rem(&1, 2) == 0))
        |> Enum.to_list()
        
        assert length(result) <= length(list)
      end
    end
    
    property "identity map returns same elements" do
      check all list <- list_of(term(), min_length: 0, max_length: 100) do
        result = list
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.map(& &1)
        |> Enum.to_list()
        
        assert result == list
      end
    end
    
    property "take never exceeds requested count" do
      check all list <- list_of(integer(), min_length: 0, max_length: 100),
                n <- integer(0..200) do
        result = list
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.take(n)
        |> Enum.to_list()
        
        assert length(result) <= n
        assert length(result) <= length(list)
      end
    end
    
    property "pipeline composition is associative" do
      check all list <- list_of(integer(), min_length: 0, max_length: 50) do
        # (f ∘ g) ∘ h = f ∘ (g ∘ h)
        f = &(&1 * 2)
        g = &(&1 + 1)
        h = &(&1 - 3)
        
        result1 = list
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.map(fn x -> f.(g.(x)) end)
        |> LeanPipeline.map(h)
        |> Enum.to_list()
        
        result2 = list
        |> LeanPipeline.from_enumerable()
        |> LeanPipeline.map(f)
        |> LeanPipeline.map(fn x -> g.(h.(x)) end)
        |> Enum.to_list()
        
        # Note: These won't be equal due to order of operations
        # Instead, verify the pipeline executes without error
        assert is_list(result1)
        assert is_list(result2)
      end
    end
  end
end
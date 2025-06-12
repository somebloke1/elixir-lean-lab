defmodule ElixirLeanLab.Builder.Behavior do
  @moduledoc """
  Common behavior for all VM builders.
  
  This module defines the contract that all builders must implement
  and provides shared functionality to avoid code duplication.
  """

  alias ElixirLeanLab.Config
  alias ElixirLeanLab.Builder.{Utils, Common}

  @doc """
  Defines the required callbacks for a VM builder.
  """
  @callback validate_dependencies() :: :ok | {:error, String.t()}
  @callback estimate_size(Config.t()) :: String.t()
  @callback build(Config.t()) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Runs the complete build pipeline with proper error handling and cleanup.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour ElixirLeanLab.Builder.Behavior
      
      alias ElixirLeanLab.{Config, Builder}
      alias ElixirLeanLab.Builder.Utils
      
      # Import common utilities
      import Utils, only: [get_file_size_mb: 1]
      
      def run(config) do
        with :ok <- validate_dependencies(),
             {:ok, state} <- prepare(config),
             {:ok, artifacts} <- build(state),
             {:ok, image_path} <- package(artifacts, config) do
          
          Builder.report_size(image_path)
          
          {:ok, %{
            image: image_path,
            type: builder_type(),
            size_mb: get_file_size_mb(image_path),
            metadata: Map.get(artifacts, :metadata, %{})
          }}
        else
          {:error, reason} = error ->
            cleanup(config)
            error
        end
      end
      
      @doc false
      def cleanup(_state), do: :ok
      
      # Default implementations that can be overridden
      @doc false
      def validate_dependencies(), do: :ok
      
      @doc false
      def estimate_size(%Config{target_size: target}), do: "~#{target}MB"
      
      defoverridable [cleanup: 1, validate_dependencies: 0, estimate_size: 1]
      
      # Builder-specific type identifier
      defp builder_type do
        __MODULE__
        |> Module.split()
        |> List.last()
        |> String.downcase()
        |> String.to_atom()
      end
    end
  end
end
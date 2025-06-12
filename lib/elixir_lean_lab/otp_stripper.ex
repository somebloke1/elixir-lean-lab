defmodule ElixirLeanLab.OTPStripper do
  @moduledoc """
  OTP application stripping configuration for minimal VM builds.
  
  Determines which OTP applications can be safely removed based on
  the target application's dependencies.
  """

  # OTP applications that are almost always safe to remove
  @always_remove ~w(
    diameter
    eldap
    erl_docgen
    et
    ftp
    jinterface
    megaco
    odbc
    snmp
    tftp
    wx
    xmerl
    debugger
    observer
    reltool
    common_test
    eunit
    dialyzer
    edoc
    erl_interface
    parsetools
    tools
  )

  # OTP applications that might be needed depending on use case
  @conditional_remove %{
    # SSH support
    ssh: "Remote shell access, deployment",
    # SSL/TLS support  
    ssl: "HTTPS, secure connections",
    public_key: "Certificate handling",
    # Web/HTTP
    inets: "HTTP client/server",
    # Database
    mnesia: "Distributed database",
    # Development
    runtime_tools: "Runtime introspection",
    sasl: "System architecture support libraries",
    # Parsing
    syntax_tools: "Code parsing and transformation"
  }

  # Core OTP applications that should never be removed
  @never_remove ~w(
    kernel
    stdlib
    compiler
    crypto
    erts
    elixir
    logger
    iex
    mix
  )

  @doc """
  Get list of OTP applications to remove for a given configuration.
  """
  def applications_to_remove(opts \\ []) do
    keep_ssh = opts[:ssh] || false
    keep_ssl = opts[:ssl] || false
    keep_http = opts[:http] || false
    keep_mnesia = opts[:mnesia] || false
    keep_dev_tools = opts[:dev_tools] || false
    
    conditional = []
    conditional = if keep_ssh, do: conditional, else: [:ssh | conditional]
    conditional = if keep_ssl, do: conditional, else: [:ssl, :public_key | conditional]
    conditional = if keep_http, do: conditional, else: [:inets | conditional]
    conditional = if keep_mnesia, do: conditional, else: [:mnesia | conditional]
    conditional = if keep_dev_tools, do: conditional, else: [:runtime_tools, :sasl, :syntax_tools | conditional]
    
    @always_remove ++ Enum.map(conditional, &to_string/1)
  end

  @doc """
  Generate shell commands to remove OTP applications.
  """
  def removal_commands(erlang_lib_path, opts \\ []) do
    apps_to_remove = applications_to_remove(opts)
    
    base_cmd = "cd #{erlang_lib_path} && rm -rf"
    
    # Group apps into chunks to avoid command line length limits
    apps_to_remove
    |> Enum.chunk_every(10)
    |> Enum.map(fn chunk ->
      apps = Enum.map(chunk, &"#{&1}-*") |> Enum.join(" ")
      "#{base_cmd} #{apps}"
    end)
  end

  @doc """
  Calculate estimated size savings.
  """
  def estimate_savings(opts \\ []) do
    # Rough estimates in MB
    app_sizes = %{
      "wx" => 15.2,
      "debugger" => 0.8,
      "observer" => 2.1,
      "dialyzer" => 3.5,
      "common_test" => 4.2,
      "eunit" => 1.1,
      "tools" => 2.3,
      "xmerl" => 2.8,
      "eldap" => 0.5,
      "diameter" => 3.1,
      "snmp" => 4.5,
      "megaco" => 6.2,
      "ssh" => 2.1,
      "ssl" => 3.8,
      "inets" => 1.9,
      "mnesia" => 2.4
    }
    
    apps_to_remove = applications_to_remove(opts)
    
    total_savings = apps_to_remove
    |> Enum.map(&Map.get(app_sizes, &1, 0.5))
    |> Enum.sum()
    
    {total_savings, length(apps_to_remove)}
  end

  @doc """
  Generate Dockerfile RUN command for stripping OTP.
  """
  def dockerfile_commands(opts \\ []) do
    """
    # Remove unnecessary OTP applications
    RUN cd /usr/local/lib/erlang/lib && \\
        rm -rf #{applications_to_remove(opts) |> Enum.map(&"#{&1}-*") |> Enum.join(" \\\n               ")}

    # Remove documentation and source files
    RUN find /usr/local/lib/erlang -name "*.html" -delete && \\
        find /usr/local/lib/erlang -name "*.pdf" -delete && \\
        find /usr/local/lib/erlang -name "src" -type d -exec rm -rf {} + 2>/dev/null || true && \\
        find /usr/local/lib/erlang -name "examples" -type d -exec rm -rf {} + 2>/dev/null || true && \\
        find /usr/local/lib/erlang -name "doc" -type d -exec rm -rf {} + 2>/dev/null || true

    # Remove Elixir source files and docs (keep compiled BEAM files)
    RUN find /usr/local/lib/elixir -name "*.ex" -delete && \\
        find /usr/local/lib/elixir -name "*.html" -delete && \\
        find /usr/local/lib/elixir -name "*.md" -delete
    """
  end
end
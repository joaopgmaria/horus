defmodule Horus.Blueprint.Operator.Registry do
  @moduledoc """
  Registry of all available Blueprint DSL operators.

  Provides compile-time composition of operator combinators and runtime
  dispatching of tokens to operators for AST construction.

  ## Operator Registration

  Operators are registered in application configuration (`config/config.exs`).
  This allows different operators to be enabled per environment, enabling
  testing new operators in dev/test before promoting to production.

  Configuration is read at compile time, so operators are still "baked in"
  for fast performance, but can differ between environments.

  Order matters - operators are tried in sequence, so more specific operators
  should be listed before more generic ones.

  Example configuration:
      config :horus, :blueprint_operators, [
        Horus.Blueprint.Operator.Presence,   # "exists" / "is required" / "is present" (before "is")
        Horus.Blueprint.Operator.TypeCheck,  # "is a" (before "is")
        Horus.Blueprint.Operator.Equality,   # "equals" or "is"
        Horus.Blueprint.Operator.Conditional # "if...then"
      ]

  ## Architecture

  The registry pattern enables:
  - **Modularity**: Each operator is self-contained
  - **Extensibility**: Add operators without modifying parser
  - **Testability**: Operators can be tested in isolation
  - **Plugin Support**: External packages can provide operators (future)

  ## Compile-Time Validation

  The registry validates operator registrations at compile time:
  - No duplicate operator names
  - All operators implement the Operator behaviour

  Call `validate!/0` during module compilation to catch configuration errors early.
  """

  import NimbleParsec

  # Registered operators - read from application config at compile time
  # This allows different operators to be enabled per environment (dev/test/prod)
  # Configuration is in config/config.exs and can be overridden per environment
  #
  # Order matters! More specific operators before generic ones:
  # - "exists" / "is required" / "is present" must come before "is"
  # - "is a" must come before "is"
  @operators Application.compile_env(:horus, :blueprint_operators, [])

  @doc """
  Returns the list of all registered operators.

  ## Examples

      iex> Registry.list_all_operators()
      [Operators.Presence, Operators.IsA, Operators.Equals, Operators.Conditional]
  """
  @spec list_all_operators() :: [module()]
  def list_all_operators, do: @operators

  @doc """
  Builds a NimbleParsec combinator that tries all registered operators.

  The combinator uses `choice/1` to try operators in order. The first
  operator that matches wins.

  ## Examples

      iex> ctx = Context.build()
      iex> combinator = Registry.build_combinator(ctx)
      # Returns a choice combinator of all operators
  """
  @spec build_combinator(context :: map()) :: NimbleParsec.t()
  def build_combinator(context) do
    case @operators do
      [single_operator] ->
        # Single operator - return its combinator directly (choice requires 2+ alternatives)
        single_operator.parser_combinator(context)

      operators ->
        # Multiple operators - wrap in choice
        operators
        |> Enum.map(& &1.parser_combinator(context))
        |> choice()
    end
  end

  @doc """
  Converts parsed tokens to an AST expression.

  Dispatches tokens to the appropriate operator based on the expression tag.
  Raises an error if no operator matches the token structure.

  ## Examples

      iex> tokens = [{:presence, [{:placeholder, "field"}, {:operator, :presence}]}]
      iex> Registry.tokens_to_ast(tokens)
      %ComparisonExpression{operator: :presence, ...}
  """
  @spec tokens_to_ast(tokens :: list()) :: Horus.Blueprint.AST.Expression.t()
  def tokens_to_ast(tokens) do
    find_operator_and_build_ast(@operators, tokens) ||
      raise "Unknown token structure: #{inspect(tokens)}"
  end

  # Private helper to find the matching operator and build AST
  defp find_operator_and_build_ast(operators, tokens) do
    Enum.find_value(operators, fn mod ->
      name = mod.operator_name()

      case tokens do
        [{^name, _} | _] -> mod.tokens_to_ast(tokens)
        _ -> nil
      end
    end)
  end

  @doc """
  Validates the operator registry at compile time.

  Checks for:
  - Duplicate operator names
  - All modules implement the Operator behaviour

  Raises a compile-time error if validation fails.

  ## Usage

  Call this in the parser module during compilation:

      @parser_context Context.build()
      Registry.validate!()

  This ensures configuration errors are caught at compile time.
  """
  @spec validate!() :: :ok
  def validate! do
    validate_no_duplicate_names()
    validate_all_implement_behaviour()
    :ok
  end

  # Private validation functions

  defp validate_no_duplicate_names do
    names = Enum.map(@operators, & &1.operator_name())
    duplicates = names -- Enum.uniq(names)

    if duplicates != [] do
      raise "Duplicate operator names found: #{inspect(duplicates)}"
    end
  end

  defp validate_all_implement_behaviour do
    @operators
    |> Enum.each(fn mod ->
      unless function_exported?(mod, :operator_name, 0) and
               function_exported?(mod, :parser_combinator, 1) and
               function_exported?(mod, :tokens_to_ast, 1) do
        raise "Module #{inspect(mod)} does not implement Horus.Blueprint.Operator behaviour"
      end
    end)
  end
end

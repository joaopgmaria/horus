defmodule Horus.Blueprint.Operator.Registry do
  @moduledoc """
  Registry of all available Blueprint DSL operators.

  Provides compile-time composition of operator combinators and runtime
  dispatching of tokens to operators for AST construction.

  ## Operator Registration

  Operators are registered by adding them to the `@operators` module attribute.
  Order matters - operators are tried in sequence, so more specific operators
  should be listed before more generic ones.

  Example:
      @operators [
        Operators.Required,    # "is required" (before "is")
        Operators.IsA,        # "is a" (before "is")
        Operators.Equals,     # "equals" or "is"
        Operators.Conditional # "if...then"
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
  - No duplicate expression tags
  - All operators implement the Operator behaviour

  Call `validate!/0` during module compilation to catch configuration errors early.
  """

  import NimbleParsec

  alias Horus.Blueprint.Operator

  # Registered operators - populated as we migrate them
  # Order matters! More specific operators before generic ones:
  # - "is required" must come before "is"
  # - "is a" must come before "is"
  @operators [
    # "is required"
    Operator.Required
  ]

  @doc """
  Returns the list of all registered operators.

  ## Examples

      iex> Registry.list_all_operators()
      [Operators.Required, Operators.IsA, Operators.Equals, Operators.Conditional]
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
      [] ->
        # No operators registered yet - return a failing combinator
        empty()

      operators ->
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

      iex> tokens = [{:required_check, [{:placeholder, "field"}, {:operator, :required}]}]
      iex> Registry.tokens_to_ast(tokens)
      %ComparisonExpression{operator: :required, ...}
  """
  @spec tokens_to_ast(tokens :: list()) :: Horus.Blueprint.AST.Expression.t()
  def tokens_to_ast(tokens) do
    if @operators == [] do
      raise "No operators registered in Registry"
    end

    find_operator_and_build_ast(@operators, tokens) ||
      raise "Unknown token structure: #{inspect(tokens)}"
  end

  # Private helper to find the matching operator and build AST
  defp find_operator_and_build_ast(operators, tokens) do
    Enum.find_value(operators, fn mod ->
      tag = mod.expression_tag()

      case tokens do
        [{^tag, _} | _] -> mod.tokens_to_ast(tokens)
        _ -> nil
      end
    end)
  end

  @doc """
  Validates the operator registry at compile time.

  Checks for:
  - Duplicate operator names
  - Duplicate expression tags
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
    # Skip validation if no operators registered yet
    if @operators == [] do
      :ok
    else
      validate_no_duplicate_names()
      validate_no_duplicate_tags()
      validate_all_implement_behaviour()
      :ok
    end
  end

  # Private validation functions

  defp validate_no_duplicate_names do
    names = Enum.map(@operators, & &1.operator_name())
    duplicates = names -- Enum.uniq(names)

    if duplicates != [] do
      raise "Duplicate operator names found: #{inspect(duplicates)}"
    end
  end

  defp validate_no_duplicate_tags do
    tags = Enum.map(@operators, & &1.expression_tag())
    duplicates = tags -- Enum.uniq(tags)

    if duplicates != [] do
      raise "Duplicate expression tags found: #{inspect(duplicates)}"
    end
  end

  defp validate_all_implement_behaviour do
    @operators
    |> Enum.each(fn mod ->
      unless function_exported?(mod, :operator_name, 0) and
               function_exported?(mod, :expression_tag, 0) and
               function_exported?(mod, :parser_combinator, 1) and
               function_exported?(mod, :tokens_to_ast, 1) do
        raise "Module #{inspect(mod)} does not implement Horus.Blueprint.Operator behaviour"
      end
    end)
  end
end

defmodule Horus.Blueprint.AST.Operator.Registry do
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
        Horus.Blueprint.AST.Operator.Presence,   # "exists" / "is required" / "is present" (before "is")
        Horus.Blueprint.AST.Operator.TypeCheck,  # "is a" (before "is")
        Horus.Blueprint.AST.Operator.Equality,   # "equals" or "is"
        Horus.Blueprint.AST.Operator.Conditional # "if...then"
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
  Builds the complete recursive grammar for the DSL based on registered operators.

  This function dynamically constructs the layered grammar (precedence levels)
  at compile time. It handles atomic, unary prefix, and binary infix operators.

  ## Parameters
  - `context` - Parser context map
  - `primary_choice_parsec` - Name of the parsec rule for the top-level expression (used for recursion in parentheses)

  ## Returns
  A NimbleParsec combinator representing the lowest precedence level (top-level).
  """
  @spec build_recursive_grammar(context :: map(), primary_choice_parsec :: atom()) ::
          NimbleParsec.t()
  def build_recursive_grammar(context, primary_choice_parsec) do
    # 1. Build the primary (atomic) combinator
    # This includes field operators, literals, and parenthesized expressions
    primary =
      choice([
        # Parentheses
        ignore(string("("))
        |> ignore(context.optional_whitespace)
        |> parsec(primary_choice_parsec)
        |> ignore(context.optional_whitespace)
        |> ignore(string(")")),
        # Atomic field operators (Registry)
        build_atomic_combinator(context),
        # Primary expressions (Registry)
        build_primary_combinator(context)
      ])

    # 2. Group non-atomic operators by precedence
    non_atomic_levels =
      @operators
      |> Enum.filter(&(not &1.atomic?()))
      |> Enum.group_by(& &1.precedence())
      |> Enum.sort(:desc)

    # 3. Layer the operators
    # We start with primary and wrap it in each subsequent precedence level
    Enum.reduce(non_atomic_levels, primary, fn {_precedence, ops}, inner_level ->
      # Check the first op to determine type (assume homogeneous level)
      first_op = List.first(ops)

      if first_op.operator_type() == :unary_prefix do
        build_unary_level(context, ops, inner_level)
      else
        build_binary_level(context, ops, inner_level)
      end
    end)
  end

  # Builds choice of all primary operators (literals, etc.)
  defp build_primary_combinator(context) do
    @operators
    |> Enum.filter(&(&1.operator_type() == :primary))
    |> case do
      [] ->
        empty()

      [single_operator] ->
        single_operator.parser_combinator(context)
        |> reduce({__MODULE__, :tokens_to_ast, []})

      operators ->
        operators
        |> Enum.map(& &1.parser_combinator(context))
        |> choice()
        |> reduce({__MODULE__, :tokens_to_ast, []})
    end
  end

  # Builds choice of all atomic operators
  defp build_atomic_combinator(context) do
    @operators
    |> Enum.filter(fn op -> op.atomic?() and op.operator_name() != :literal end)
    |> case do
      [] ->
        empty()

      [single_operator] ->
        single_operator.parser_combinator(context)
        |> reduce({__MODULE__, :tokens_to_ast, []})

      operators ->
        operators
        |> Enum.map(& &1.parser_combinator(context))
        |> choice()
        |> reduce({__MODULE__, :tokens_to_ast, []})
    end
  end

  # Helper to build a unary precedence level (tries operators then falls back to inner)
  defp build_unary_level(context, ops, inner_level) do
    # Build choice of unary operators
    unary_choices =
      ops
      |> Enum.map(fn op ->
        op.parser_combinator(context)
        |> ignore(context.whitespace)
        |> concat(inner_level)
        |> tag(op.operator_name())
        |> reduce({__MODULE__, :tokens_to_ast, []})
      end)

    unary_ops =
      case unary_choices do
        [single] -> single
        choices -> choice(choices)
      end

    choice([unary_ops, inner_level])
  end

  # Helper to build a binary precedence level (inner op inner op inner...)
  defp build_binary_level(context, ops, inner_level) do
    # first = inner
    # rest = repeat( choice([op1, op2]) inner )
    # then reduce binary tree
    op_forms =
      ops
      |> Enum.map(fn op ->
        op.parser_combinator(context)
        |> tag(op.operator_name())
      end)

    op_choice =
      case op_forms do
        [single] -> single
        forms -> choice(forms)
      end

    inner_level
    |> repeat(
      ignore(context.whitespace)
      |> concat(op_choice)
      |> ignore(context.whitespace)
      |> concat(inner_level)
    )
    |> reduce({__MODULE__, :reduce_binary_tokens, []})
  end

  @doc false
  def reduce_binary_tokens([left | rest]) do
    # rest is a flat list of tokens: [{:op_name, [form]}, right_ast, {:op_name, [form]}, right_next_ast, ...]
    rest
    |> Enum.chunk_every(2)
    |> Enum.reduce(left, fn [{op_name, _form}, right], acc ->
      tokens_to_ast([{op_name, [acc, right]}])
    end)
  end

  @doc """
  Converts parsed tokens to an AST expression.

  Dispatches tokens to the appropriate operator based on the name.
  Raises an error if no operator matches the token structure.

  ## Examples

      iex> tokens = [{:presence, [{:placeholder, "field"}, {:operator, :presence}]}]
      iex> Registry.tokens_to_ast(tokens)
      %Comparison{operator: :presence, ...}
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
        raise "Module #{inspect(mod)} does not implement Horus.Blueprint.AST.Operator behaviour"
      end
    end)
  end
end

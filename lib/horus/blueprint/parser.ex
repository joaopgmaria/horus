defmodule Horus.Blueprint.Parser do
  @moduledoc """
  NimbleParsec-based parser for blueprint DSL.

  Parses natural language validation rules into Abstract Syntax Trees (AST).

  ## Supported Operators

  - **Presence** - Field existence validation
    - Forms: "exists", "must exist", "should exist", "is required", "is present",
      "must be present", "should be present", "must be filled in", "should be filled in"
    - Example: `${email} exists`, `${email} is required`

  Additional operators (type_check, equality, conditional) will be added in separate PRs
  following the operator registry pattern.

  ## Examples

      iex> parse_dsl("${email} exists")
      {:ok, %Comparison{operator: :presence, ...}}

      iex> parse_dsl("${email} is required")
      {:ok, %Comparison{operator: :presence, ...}}

      iex> parse_dsl("${email} must be present")
      {:ok, %Comparison{operator: :presence, ...}}
  """

  import NimbleParsec

  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Operator.Registry
  alias Horus.Blueprint.Parser.Context

  # Build parser context at compile time
  @parser_context Context.build()
  Registry.validate!()

  # All operators are now registered via the Operator Registry
  # Operators are loaded from application config and composed at compile time
  # Grammar Structure:
  # Grammar
  # The grammar is now dynamically built by the Registry based on operator precedences.
  # It automatically layers atomic (presence, etc.), unary (not), and binary (and, or) operators.
  defparsec(
    :parse_expression,
    Registry.build_recursive_grammar(@parser_context, :parse_expression)
  )

  # Top-level DSL expression
  dsl_expr =
    ignore(@parser_context.optional_whitespace)
    |> parsec(:parse_expression)
    |> ignore(@parser_context.optional_whitespace)
    |> eos()

  defparsec(:parse, dsl_expr)

  @doc """
  Parses a Horus DSL string into an AST.

  Returns `{:ok, ast}` or `{:error, error_map}`.
  """
  @spec parse_dsl(String.t()) ::
          {:ok, Expression.t()}
          | {:error, map()}
  def parse_dsl(dsl) when is_binary(dsl) do
    trimmed = String.trim(dsl)

    if trimmed == "" do
      {:error, %{message: "Unexpected input: empty string", line: 1, column: 1}}
    else
      case parse(trimmed) do
        {:ok, [ast], "", _, _, _} ->
          {:ok, ast}

        {:ok, _, rest, _, line, col} ->
          # This should be unreachable due to eos() in grammar
          {:error, %{message: "Unexpected input: #{inspect(rest)}", line: line, column: col}}

        {:error, _reason, rest, _, line, col} ->
          # Provide a more user-friendly error message
          friendly_msg = build_friendly_error_message(rest, dsl)
          {:error, %{message: friendly_msg, line: line, column: col}}
      end
    end
  end

  # Helper to build a user-friendly error message
  defp build_friendly_error_message(rest, original) do
    cond do
      (String.starts_with?(rest, "${") and not String.contains?(rest, "}")) or
          (String.contains?(original, "${") and not String.contains?(original, "}")) ->
        "Unexpected input: malformed placeholder (missing closing brace)"

      rest != "" ->
        "Unexpected input: #{String.slice(rest, 0..20)}"

      true ->
        "Unexpected input: empty or invalid expression"
    end
  end

  @doc false
  def build_ast([ast_node]) do
    {:ok, ast_node}
  end

  # Helper to reduce binary logical operators (AND/OR) using the Registry
  @doc false
  def reduce_binary([left | rest], operator) do
    Enum.reduce(rest, left, fn {^operator, [right]}, acc ->
      Registry.tokens_to_ast([{operator, [acc, right]}])
    end)
  end
end

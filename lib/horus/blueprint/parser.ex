defmodule Horus.Blueprint.Parser do
  @moduledoc """
  NimbleParsec-based parser for blueprint DSL.

  Parses natural language validation rules into Abstract Syntax Trees (AST).

  ## Supported Operators (MVP)

  - `is a` - Type checking: `${field} is a string`
  - `is required` - Presence: `${field} is required`
  - `is` / `equals` - Equality: `${field} is ${value}` (where `is` is alias for `equals`)
  - `if...then` - Conditional: `if ${country} is a string then ${postal_code} is required`

  ## Examples

      iex> parse_dsl("${field} is a string")
      {:ok, %ComparisonExpression{...}}

      iex> parse_dsl("${field} is required")
      {:ok, %ComparisonExpression{operator: :required, ...}}

      iex> parse_dsl("if ${country} is a string then ${postal_code} is required")
      {:ok, %ConditionalExpression{...}}
  """

  import NimbleParsec

  alias Horus.Blueprint.AST.{
    ComparisonExpression,
    ConditionalExpression,
    FieldExpression,
    TypeExpression
  }

  alias Horus.Blueprint.Operator.Registry
  alias Horus.Blueprint.Parser.Context

  # Build parser context at compile time
  @parser_context Context.build()
  Registry.validate!()

  # Whitespace (one or more spaces/tabs)
  whitespace = ascii_string([?\s, ?\t], min: 1)
  optional_whitespace = ascii_string([?\s, ?\t], min: 0)

  # Placeholder: ${identifier}
  # Identifier can contain lowercase letters, underscores, and numbers
  placeholder =
    ignore(string("${"))
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 1)
    |> ignore(string("}"))
    |> unwrap_and_tag(:placeholder)

  # Type names: string, integer, number, boolean, array, object
  type_name =
    choice([
      string("string") |> replace(:string),
      string("integer") |> replace(:integer),
      string("number") |> replace(:number),
      string("boolean") |> replace(:boolean),
      string("array") |> replace(:array),
      string("object") |> replace(:object)
    ])
    |> unwrap_and_tag(:type)

  # Operators from Registry (migrated operators)
  registry_operators = Registry.build_combinator(@parser_context)

  # Operators not yet migrated to Registry
  # Note: Order matters! Check "is a" before standalone "is"
  op_is_a =
    string("is")
    |> ignore(whitespace)
    |> string("a")
    |> replace(:is_a)
    |> unwrap_and_tag(:operator)

  op_equals = string("equals") |> replace(:equals) |> unwrap_and_tag(:operator)

  # Standalone "is" as alias for equals
  op_is = string("is") |> replace(:equals) |> unwrap_and_tag(:operator)

  # Comparison expression: ${field} <operator> [<value>]
  # Type check: ${field} is a <type>
  type_check_expr =
    placeholder
    |> ignore(whitespace)
    |> concat(op_is_a)
    |> ignore(whitespace)
    |> concat(type_name)
    |> tag(:type_check)

  # Equality check: ${field} equals ${value} OR ${field} is ${value}
  equality_expr =
    placeholder
    |> ignore(whitespace)
    |> concat(choice([op_equals, op_is]))
    |> ignore(whitespace)
    |> concat(placeholder)
    |> tag(:equality_check)

  # Comparison expression (any of the above)
  # Try Registry operators first (includes migrated Required with all its forms),
  # then fall back to old inline operators (IsA, Equals) not yet migrated
  comparison_expr = choice([registry_operators, type_check_expr, equality_expr])

  # Conditional expression: if <condition> then <then_expr>
  conditional_expr =
    ignore(string("if"))
    |> ignore(whitespace)
    |> concat(comparison_expr)
    |> ignore(whitespace)
    |> ignore(string("then"))
    |> ignore(whitespace)
    |> concat(comparison_expr)
    |> tag(:conditional)

  # Top-level expression
  dsl_expr =
    optional_whitespace
    |> ignore()
    |> choice([conditional_expr, comparison_expr])
    |> concat(optional_whitespace |> ignore())
    |> eos()

  defparsec(:parse, dsl_expr)

  @doc """
  Parses a DSL string into an AST.

  Returns `{:ok, ast}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> parse_dsl("${field} is a string")
      {:ok, %ComparisonExpression{
        operator: :is_a,
        left: %FieldExpression{path: "${field}"},
        right: %TypeExpression{type: :string}
      }}

      iex> parse_dsl("invalid syntax")
      {:error, %{message: "...", ...}}
  """
  @spec parse_dsl(String.t()) ::
          {:ok,
           FieldExpression.t()
           | TypeExpression.t()
           | ComparisonExpression.t()
           | ConditionalExpression.t()}
          | {:error, map()}
  def parse_dsl(dsl) when is_binary(dsl) do
    trimmed = String.trim(dsl)

    if trimmed == "" do
      {:error, %{message: "Unexpected input: empty string", line: 1, column: 1}}
    else
      trimmed
      |> parse()
      |> case do
        {:ok, tokens, "", _, _, _} ->
          build_ast(tokens)

        {:ok, _, rest, _, line, col} ->
          {:error, %{message: "Unexpected input: #{inspect(rest)}", line: line, column: col}}

        {:error, _reason, rest, _, line, col} ->
          # Provide a more user-friendly error message
          friendly_msg = build_friendly_error_message(rest, dsl)
          {:error, %{message: friendly_msg, line: line, column: col}}
      end
    end
  end

  defp build_friendly_error_message(rest, original) do
    cond do
      String.starts_with?(rest, "${") and not String.contains?(rest, "}") ->
        "Unexpected input: malformed placeholder (missing closing brace)"

      String.contains?(original, "${") and not String.contains?(original, "}") ->
        "Unexpected input: malformed placeholder (missing closing brace)"

      rest != "" ->
        "Unexpected input: #{String.slice(rest, 0..20)}"

      true ->
        "Unexpected input: invalid syntax"
    end
  end

  @doc false
  def build_ast(tokens) do
    {:ok, tokens_to_ast(tokens)}
  rescue
    e -> {:error, %{message: Exception.message(e), error: e}}
  end

  # Transform tokens to AST
  defp tokens_to_ast([{:conditional, tokens}]) do
    # Conditional: if <condition> then <then_expr>
    # tokens is a flat list, need to split into condition and then parts
    [condition_tokens, then_tokens] = split_conditional_tokens(tokens)

    %ConditionalExpression{
      condition: tokens_to_ast([condition_tokens]),
      then_expr: tokens_to_ast([then_tokens])
    }
  end

  defp tokens_to_ast([{:type_check, [{:placeholder, field}, {:operator, :is_a}, {:type, type}]}]) do
    %ComparisonExpression{
      operator: :is_a,
      left: %FieldExpression{path: "${#{field}}", placeholder?: true},
      right: %TypeExpression{type: type}
    }
  end

  defp tokens_to_ast([{:presence, _} | _] = tokens) do
    # Delegate to Registry for migrated operators
    Registry.tokens_to_ast(tokens)
  end

  defp tokens_to_ast([
         {:equality_check, [{:placeholder, field}, {:operator, :equals}, {:placeholder, value}]}
       ]) do
    %ComparisonExpression{
      operator: :equals,
      left: %FieldExpression{path: "${#{field}}", placeholder?: true},
      right: %FieldExpression{path: "${#{value}}", placeholder?: true}
    }
  end

  # Split conditional tokens into condition and then parts
  # The tokens list contains two tagged groups: the condition and the then expression
  defp split_conditional_tokens(tokens) do
    # Find the index where the second expression starts
    # Both condition and then are tagged expressions (type_check, required_check, or equality_check)
    case tokens do
      [condition_tag | rest] when is_tuple(condition_tag) ->
        # Find where the next tagged expression starts
        then_index = Enum.find_index(rest, &is_tuple/1)

        if then_index do
          condition = condition_tag
          then_expr = Enum.at(rest, then_index)
          [condition, then_expr]
        else
          # Only one expression found, something's wrong
          raise "Invalid conditional structure: expected two expressions"
        end

      _ ->
        raise "Invalid conditional structure: #{inspect(tokens)}"
    end
  end
end

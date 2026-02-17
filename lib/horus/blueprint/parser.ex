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
  registry_operators = Registry.build_combinator(@parser_context)

  # Top-level DSL expression
  dsl_expr =
    @parser_context.optional_whitespace
    |> ignore()
    |> concat(registry_operators)
    |> concat(@parser_context.optional_whitespace |> ignore())
    |> eos()

  defparsec(:parse, dsl_expr)

  @doc """
  Parses a DSL string into an AST.

  Returns `{:ok, ast}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> parse_dsl("${email} exists")
      {:ok, %Comparison{
        operator: :presence,
        left: %Field{path: "${email}", placeholder?: true},
        right: nil
      }}

      iex> parse_dsl("${email} is required")
      {:ok, %Comparison{operator: :presence, ...}}

      iex> parse_dsl("invalid syntax")
      {:error, %{message: "...", ...}}
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
        {:ok, tokens, "", _, _, _} ->
          build_ast(tokens)

        {:ok, _, rest, _, line, col} ->
          # This should be unreachable due to eos() in grammar, but we keep it for safety
          # and to provide a clear error if grammar changes.
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
    # tokens_to_ast will raise if structure is unknown, but since it's called
    # only after a successful parse which uses the same operators, it shouldn't.
    # We let it raise to be caught by Dialyzer if any branch is missing.
    {:ok, tokens_to_ast(tokens)}
  end

  # Transform tokens to AST - delegate all to Registry
  defp tokens_to_ast(tokens) do
    Registry.tokens_to_ast(tokens)
  end
end

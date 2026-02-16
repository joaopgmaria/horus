defmodule Horus.Blueprint.Parser.Context do
  @moduledoc """
  Shared parsing primitives for operators.

  Provides common NimbleParsec combinators used across operator implementations.
  These primitives are extracted from the parser to enable operator modularity
  while maintaining consistent parsing behavior.

  ## Usage

  Operators receive a context map containing all primitives via their
  `parser_combinator/1` callback:

      def parser_combinator(ctx) do
        ctx.placeholder
        |> ignore(ctx.whitespace)
        |> string("my_operator")
        |> tag(:my_operator_check)
      end

  ## Available Primitives

  - `placeholder` - Parses `${identifier}` placeholders
  - `whitespace` - Required whitespace (1+ spaces/tabs)
  - `optional_whitespace` - Optional whitespace
  - `type_name` - Parses type names (string, integer, number, boolean, array, object)
  - `modal_verb` - Parses modal verbs (is, must be, should be) - all equivalent
  """

  import NimbleParsec

  @doc """
  Builds a parser context with all shared combinators.

  Returns a map containing NimbleParsec combinators that operators can use
  to build their parsing logic.

  ## Examples

      iex> ctx = Context.build()
      iex> Map.keys(ctx)
      [:placeholder, :whitespace, :optional_whitespace, :type_name, :modal_verb]
  """
  @spec build() :: map()
  def build do
    %{
      placeholder: placeholder(),
      whitespace: whitespace(),
      optional_whitespace: optional_whitespace(),
      type_name: type_name(),
      modal_verb: modal_verb()
    }
  end

  # Private combinators extracted from parser.ex

  # Placeholder: ${identifier}
  # Identifier can contain lowercase letters, underscores, and numbers
  defp placeholder do
    ignore(string("${"))
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 1)
    |> ignore(string("}"))
    |> unwrap_and_tag(:placeholder)
  end

  # Whitespace (one or more spaces/tabs)
  defp whitespace do
    ascii_string([?\s, ?\t], min: 1)
  end

  # Optional whitespace (zero or more spaces/tabs)
  defp optional_whitespace do
    ascii_string([?\s, ?\t], min: 0)
  end

  # Type names: string, integer, number, boolean, array, object
  defp type_name do
    choice([
      string("string") |> replace(:string),
      string("integer") |> replace(:integer),
      string("number") |> replace(:number),
      string("boolean") |> replace(:boolean),
      string("array") |> replace(:array),
      string("object") |> replace(:object)
    ])
    |> unwrap_and_tag(:type)
  end

  # Modal verbs: "is", "must be", "should be" (all equivalent)
  # Global DSL convention - these forms are interchangeable for all operators
  defp modal_verb do
    choice([
      string("must") |> ignore(whitespace()) |> string("be"),
      string("should") |> ignore(whitespace()) |> string("be"),
      string("is")
    ])
  end
end

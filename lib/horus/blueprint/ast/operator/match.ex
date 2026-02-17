defmodule Horus.Blueprint.AST.Operator.Match do
  @moduledoc """
  "match" operator - checks if field matches regex.

  ## Syntax

  All supported operator forms:
      ${field} matches /regex/
      ${field} matches ${regex_placeholder}
      ${field} must match /regex/
      ${field} should match /regex/

  ## Description

  Validates that a field matches a given regular expression. This is typically used
  to enforce specific formats in a payload.

  ## Examples

      # Number starting with + and 3 digits and followed by any digits
      "${phone} matches /\\+\\d{3}\\d*/"

      # Used in conditionals
      "if ${user} matches /customer/ then ${email} must match /.+@.+\\..+/"

  ## AST Output

  Produces a Comparison with operator `:match`:

      %Comparison{
        operator: :match,
        left: %Field{path: "${field}", placeholder?: true},
        right: %Literal{value: ~r/regex/, type: :regex}
      }

      or

      %Comparison{
        operator: :match,
        left: %Field{path: "${field}", placeholder?: true},
        right: %Literal{value: "${regex_placeholder}", type: :placeholder}
      }

  The `right` side is a `Literal` that can either contain a regex pattern (if the operator form uses a regex literal) or a placeholder (if the operator form uses a regex placeholder).
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Comparison

  @impl true
  def operator_name, do: :match

  @impl true
  def operator_type, do: :binary_infix

  @impl true
  def atomic?, do: false

  @impl true
  def operator_forms do
    [
      "matches",
      "must match",
      "should match"
    ]
  end

  # Note: parser_combinator/1 is provided by `use Horus.Blueprint.AST.Operator`

  @impl true
  def tokens_to_ast([{:match, [left, right]}]) do
    %Comparison{
      operator: :match,
      left: left,
      right: right
    }
  end
end

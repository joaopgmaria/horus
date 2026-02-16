defmodule Horus.Blueprint.Operator.Required do
  @moduledoc """
  "is required" operator - checks field presence.

  ## Syntax

      ${field} is required

  ## Description

  Validates that a field exists and is not null. This is typically used
  to enforce mandatory fields in a payload.

  ## Examples

      # Require email field
      "${email} is required"

      # Require nested field
      "${customer.address} is required"

      # Used in conditional
      "if ${type} equals customer then ${email} is required"

  ## AST Output

  Produces a ComparisonExpression with operator `:required`:

      %ComparisonExpression{
        operator: :required,
        left: %FieldExpression{path: "${field}", placeholder?: true},
        right: nil
      }

  The `right` side is `nil` because presence checks don't compare against a value.
  """

  @behaviour Horus.Blueprint.Operator

  import NimbleParsec

  alias Horus.Blueprint.AST.{ComparisonExpression, FieldExpression}

  @impl true
  def operator_name, do: :required

  @impl true
  def expression_tag, do: :required_check

  @impl true
  def parser_combinator(ctx) do
    # Pattern: ${field} is required
    # Note: Must check "is required" before standalone "is" (precedence)
    ctx.placeholder
    |> ignore(ctx.whitespace)
    |> string("is")
    |> ignore(ctx.whitespace)
    |> string("required")
    |> replace(:required)
    |> unwrap_and_tag(:operator)
    |> tag(:required_check)
  end

  @impl true
  def tokens_to_ast([{:required_check, [{:placeholder, field}, {:operator, :required}]}]) do
    %ComparisonExpression{
      operator: :required,
      left: %FieldExpression{path: "${#{field}}", placeholder?: true},
      right: nil
    }
  end
end

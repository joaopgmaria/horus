defmodule Horus.Blueprint.Operator.Required do
  @moduledoc """
  "is required" operator - checks field presence.

  ## Syntax

  Main forms (with modal verbs):
      ${field} is required
      ${field} must be required
      ${field} should be required

  Alternative forms:
      ${field} must be filled in
      ${field} must be present

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
  def operator_aliases do
    [
      "must be filled in",
      "must be present"
    ]
  end

  @impl true
  def parser_combinator(ctx) do
    # Pattern: ${field} (is|must be|should be) required
    #          ${field} must be filled in
    #          ${field} must be present
    # Note: Must check all "required" forms before standalone "is" (precedence)

    # All forms compile to the same tokens: [{:required_check, [{:placeholder, field}, {:operator, :required}]}]

    main_form =
      ctx.placeholder
      |> ignore(ctx.whitespace)
      |> ignore(ctx.modal_verb)
      |> ignore(ctx.whitespace)
      |> ignore(string("required"))
      |> concat(empty() |> replace(:required) |> unwrap_and_tag(:operator))
      |> tag(:required_check)

    filled_in_alias =
      ctx.placeholder
      |> ignore(ctx.whitespace)
      |> ignore(string("must"))
      |> ignore(ctx.whitespace)
      |> ignore(string("be"))
      |> ignore(ctx.whitespace)
      |> ignore(string("filled"))
      |> ignore(ctx.whitespace)
      |> ignore(string("in"))
      |> concat(empty() |> replace(:required) |> unwrap_and_tag(:operator))
      |> tag(:required_check)

    present_alias =
      ctx.placeholder
      |> ignore(ctx.whitespace)
      |> ignore(string("must"))
      |> ignore(ctx.whitespace)
      |> ignore(string("be"))
      |> ignore(ctx.whitespace)
      |> ignore(string("present"))
      |> concat(empty() |> replace(:required) |> unwrap_and_tag(:operator))
      |> tag(:required_check)

    # Try aliases first (more specific), then main form
    choice([filled_in_alias, present_alias, main_form])
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

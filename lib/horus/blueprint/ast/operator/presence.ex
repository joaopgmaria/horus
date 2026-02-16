defmodule Horus.Blueprint.AST.Operator.Presence do
  @moduledoc """
  "presence" operator - checks field presence.

  ## Syntax

  All supported operator forms:
      ${field} exists
      ${field} must exist
      ${field} should exist
      ${field} is required
      ${field} is present
      ${field} must be present
      ${field} should be present
      ${field} must be filled in
      ${field} should be filled in

  ## Description

  Validates that a field exists and is not null. This is typically used
  to enforce mandatory fields in a payload.

  ## Examples

      # Require email field
      "${email} exists"

      # Used in conditionals
      "if ${customer} exists customer then ${email} is required"

  ## AST Output

  Produces a Comparison with operator `:presence`:

      %Comparison{
        operator: :presence,
        left: %Field{path: "${field}", placeholder?: true},
        right: nil
      }

  The `right` side is `nil` because presence checks don't compare against a value.
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.{Comparison, Field}

  @impl true
  def operator_name, do: :presence

  @impl true
  def operator_forms do
    [
      "exists",
      "must exist",
      "should exist",
      "is required",
      "is present",
      "must be present",
      "should be present",
      "must be filled in",
      "should be filled in"
    ]
  end

  # Note: parser_combinator/1 is provided by `use Horus.Blueprint.AST.Operator`

  @impl true
  def tokens_to_ast([{:presence, [{:placeholder, field}, {:operator, :presence}]}]) do
    %Comparison{
      operator: :presence,
      left: %Field{path: "${#{field}}", placeholder?: true},
      right: nil
    }
  end
end

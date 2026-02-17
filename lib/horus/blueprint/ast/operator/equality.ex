defmodule Horus.Blueprint.AST.Operator.Equality do
  @moduledoc """
  Operator for equality comparison.

  Supports multiple natural language forms and maps to a Comparison AST node
  with the `:eq` operator.
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Comparison

  @impl true
  def operator_name, do: :equality

  @impl true
  def operator_type, do: :binary_infix

  @impl true
  def precedence, do: 50

  @impl true
  def operator_forms do
    [
      "equals",
      "is",
      "==",
      "is equal to",
      "must be",
      "should be",
      "must equal",
      "should equal"
    ]
  end

  @impl true
  def atomic?, do: false

  @impl true
  def tokens_to_ast([{:equality, [left, right]}]) do
    %Comparison{
      operator: :eq,
      left: left,
      right: right
    }
  end
end

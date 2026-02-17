defmodule Horus.Blueprint.AST.Operator.Or do
  @moduledoc """
  Logical OR operator.
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Boolean

  @impl true
  def operator_name, do: :or

  @impl true
  def operator_forms, do: ["or", "||"]

  @impl true
  def operator_type, do: :binary_infix

  @impl true
  def precedence, do: 10

  @impl true
  def parser_combinator(_ctx) do
    choice([string("or"), string("||")])
  end

  @impl true
  def atomic?, do: false

  @impl true
  def tokens_to_ast([{:or, [left_ast, right_ast]}]) do
    %Boolean{operator: :or, left: left_ast, right: right_ast}
  end
end

defmodule Horus.Blueprint.AST.Operator.And do
  @moduledoc """
  Logical AND operator.
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Boolean

  @impl true
  def operator_name, do: :and

  @impl true
  def operator_forms, do: ["and", "&&"]

  @impl true
  def operator_type, do: :binary_infix

  @impl true
  def precedence, do: 20

  @impl true
  def parser_combinator(_ctx) do
    choice([string("and"), string("&&")])
  end

  @impl true
  def atomic?, do: false

  @impl true
  def tokens_to_ast([{:and, [left_ast, right_ast]}]) do
    %Boolean{operator: :and, left: left_ast, right: right_ast}
  end
end

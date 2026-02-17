defmodule Horus.Blueprint.AST.Operator.Not do
  @moduledoc """
  Logical NOT operator.
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Boolean

  @impl true
  def operator_name, do: :not

  @impl true
  def operator_forms, do: ["not"]

  @impl true
  def operator_type, do: :unary_prefix

  @impl true
  def precedence, do: 30

  # Override to only parse the keyword "not"
  @impl true
  def parser_combinator(_ctx) do
    ignore(string("not"))
  end

  @impl true
  def atomic?, do: false

  @impl true
  def tokens_to_ast([{:not, [inner_ast]}]) do
    %Boolean{operator: :not, left: inner_ast, right: nil}
  end
end

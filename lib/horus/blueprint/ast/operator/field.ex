defmodule Horus.Blueprint.AST.Operator.Field do
  @moduledoc """
  Operator for handling plain placeholders (${field}) as primary expressions.
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Field

  @impl true
  def operator_name, do: :field

  @impl true
  def operator_type, do: :primary

  @impl true
  def operator_forms, do: []

  @impl true
  def atomic?, do: false

  @impl true
  def parser_combinator(ctx) do
    ctx.placeholder
    |> tag(:field)
  end

  @impl true
  def tokens_to_ast(field: [placeholder: field]) do
    %Field{path: "${#{field}}", placeholder?: true}
  end
end

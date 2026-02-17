defmodule Horus.Blueprint.AST.Operator.Literal do
  @moduledoc """
  Operator for handling literal values (string, atom, integer, float, boolean).
  """

  use Horus.Blueprint.AST.Operator

  alias Horus.Blueprint.AST.Expression.Literal

  @impl true
  def operator_name, do: :literal

  @impl true
  def operator_type, do: :primary

  @impl true
  def operator_forms, do: []

  @impl true
  def atomic?, do: false

  @impl true
  def parser_combinator(_ctx) do
    choice([
      string_literal(),
      atom_literal(),
      float_literal(),
      integer_literal(),
      boolean_literal(),
      regex_literal()
    ])
    |> tag(:literal)
  end

  @impl true
  def tokens_to_ast([{:literal, tokens}]) do
    case tokens do
      [{:string, val}] -> %Literal{value: val, type: :string}
      [{:atom, val}] -> %Literal{value: val, type: :atom}
      [{:integer, val}] -> %Literal{value: val, type: :integer}
      [{:float, val}] -> %Literal{value: val, type: :number}
      [{:boolean, val}] -> %Literal{value: val, type: :boolean}
      [{:regex, val}] -> %Literal{value: val, type: :regex}
      _ -> raise "Unexpected tokens for literal: #{inspect(tokens)}"
    end
  end

  # --- Combinator Definitions ---

  defp integer_literal do
    optional(string("-"))
    |> ascii_string([?0..?9], min: 1)
    |> reduce({Enum, :join, []})
    |> map({String, :to_integer, []})
    |> unwrap_and_tag(:integer)
  end

  defp float_literal do
    optional(string("-"))
    |> ascii_string([?0..?9], min: 1)
    |> string(".")
    |> ascii_string([?0..?9], min: 1)
    |> reduce({Enum, :join, []})
    |> map({String, :to_float, []})
    |> unwrap_and_tag(:float)
  end

  defp boolean_literal do
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:boolean)
  end

  defp string_literal do
    choice([
      ignore(string("\""))
      |> utf8_string([not: ?"], min: 0)
      |> ignore(string("\"")),
      ignore(string("'"))
      |> utf8_string([not: ?'], min: 0)
      |> ignore(string("'"))
    ])
    |> unwrap_and_tag(:string)
  end

  defp atom_literal do
    ignore(string(":"))
    |> ascii_string([?a..?z, ?_, ?0..?9], min: 1)
    |> map({String, :to_atom, []})
    |> unwrap_and_tag(:atom)
  end

  defp regex_literal do
    ignore(string("/"))
    |> utf8_string([not: ?/], min: 1)
    |> ignore(string("/"))
    |> unwrap_and_tag(:regex)
  end
end

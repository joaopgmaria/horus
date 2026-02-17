defmodule Horus.Blueprint.AST.Expression.Boolean do
  @moduledoc """
  Represents logical operations (AND, OR, NOT).

  ## Fields

  - `operator` - The logical operator (`:and`, `:or`, `:not`)
  - `left` - The left operand (a boolean expression)
  - `right` - The right operand (a boolean expression, optional for `:not`)

  ## Examples

      # AND operation
      %Boolean{
        operator: :and,
        left: %Comparison{operator: :presence, left: %Field{path: "${email}"}},
        right: %Comparison{operator: :presence, left: %Field{path: "${name}"}}
      }

      # NOT operation
      %Boolean{
        operator: :not,
        left: %Comparison{operator: :presence, left: %Field{path: "${email}"}}
      }
  """

  @type operator :: :and | :or | :not
  @type t :: %__MODULE__{
          operator: operator(),
          left: Horus.Blueprint.AST.boolean_expression(),
          right: Horus.Blueprint.AST.boolean_expression() | nil
        }

  @enforce_keys [:operator, :left]
  defstruct [:operator, :left, :right]

  @doc """
  Deserializes a Boolean from JSON (without "type" field).
  """
  def from_json(%{"operator" => op, "left" => left} = json) do
    %__MODULE__{
      operator: String.to_existing_atom(op),
      left: Horus.Blueprint.AST.from_json(left),
      right: if(right = json["right"], do: Horus.Blueprint.AST.from_json(right))
    }
  end

  defimpl Horus.Blueprint.AST.Expression do
    alias Horus.Blueprint.AST.Expression

    def to_json(%Horus.Blueprint.AST.Expression.Boolean{operator: op, left: left, right: right}) do
      %{
        "type" => "boolean",
        "operator" => Atom.to_string(op),
        "left" => Expression.to_json(left),
        "right" => if(right, do: Expression.to_json(right))
      }
    end

    def extract_parameters(%Horus.Blueprint.AST.Expression.Boolean{left: left, right: right}) do
      left_params = Expression.extract_parameters(left)
      right_params = if right, do: Expression.extract_parameters(right), else: []
      left_params ++ right_params
    end
  end
end

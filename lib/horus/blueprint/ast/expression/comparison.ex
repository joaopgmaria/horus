defmodule Horus.Blueprint.AST.Expression.Comparison do
  @moduledoc """
  Represents a binary comparison operation.

  Currently only supports presence checks.

  ## Operators

  - `:presence` - Presence: `${field} exists` / `${field} is required` (right is nil)

  ## Examples

      # Presence check
      %Comparison{
        operator: :presence,
        left: %Field{path: "${field}"},
        right: nil
      }
  """

  @type operator :: :presence | :eq | :match

  @type t :: %__MODULE__{
          operator: operator(),
          left: Horus.Blueprint.AST.Expression.t(),
          right: Horus.Blueprint.AST.Expression.t() | nil
        }

  @enforce_keys [:operator, :left]
  defstruct [:operator, :left, :right]

  @doc """
  Deserializes a Comparison from JSON (without "type" field).
  """
  def from_json(%{"operator" => op, "left" => left, "right" => right}) do
    %__MODULE__{
      operator: String.to_existing_atom(op),
      left: Horus.Blueprint.AST.from_json(left),
      right: if(right, do: Horus.Blueprint.AST.from_json(right))
    }
  end

  defimpl Horus.Blueprint.AST.Expression do
    alias Horus.Blueprint.AST.Expression

    def to_json(%{operator: op, left: left, right: right}) do
      %{
        "type" => "comparison",
        "operator" => Atom.to_string(op),
        "left" => Expression.to_json(left),
        "right" => if(right, do: Expression.to_json(right))
      }
    end

    def extract_parameters(%{left: left, right: right}) do
      left_params = Expression.extract_parameters(left)
      right_params = if right, do: Expression.extract_parameters(right), else: []
      left_params ++ right_params
    end
  end
end

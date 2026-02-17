defmodule Horus.Blueprint.AST.Expression.Conditional do
  @moduledoc """
  Represents if/then conditional logic.

  Used for conditional validation rules where one validation depends on another.

  ## Fields

  - `condition` - The condition expression (must evaluate to boolean)
  - `then_expr` - The expression to evaluate if condition is true

  ## Examples

      # "if ${customer} exists then ${email} is required"
      %Conditional{
        condition: %Comparison{
          operator: :presence,
          left: %Field{path: "${customer}"},
          right: nil
        },
        then_expr: %Comparison{
          operator: :presence,
          left: %Field{path: "${email}"},
          right: nil
        }
      }
  """

  @type t :: %__MODULE__{
          condition: Horus.Blueprint.AST.Expression.t(),
          then_expr: Horus.Blueprint.AST.Expression.t()
        }

  @enforce_keys [:condition, :then_expr]
  defstruct [:condition, :then_expr]

  @doc """
  Deserializes a Conditional from JSON (without "type" field).
  """
  def from_json(%{"condition" => cond, "then" => then_expr}) do
    %__MODULE__{
      condition: Horus.Blueprint.AST.from_json(cond),
      then_expr: Horus.Blueprint.AST.from_json(then_expr)
    }
  end

  defimpl Horus.Blueprint.AST.Expression do
    alias Horus.Blueprint.AST.Expression

    def to_json(%{condition: cond, then_expr: then_expr}) do
      %{
        "type" => "conditional",
        "condition" => Expression.to_json(cond),
        "then" => Expression.to_json(then_expr)
      }
    end

    def extract_parameters(%{condition: cond, then_expr: then_expr}) do
      cond_params = Expression.extract_parameters(cond)
      then_params = Expression.extract_parameters(then_expr)
      cond_params ++ then_params
    end
  end
end

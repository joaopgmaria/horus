defmodule Horus.Blueprint.AST.Expression.Literal do
  @moduledoc """
  Represents a literal value in the AST.

  ## Fields

  - `value` - The literal value (can be string, number, boolean, etc.)
  - `type` - The data type of the literal (aligns with `Horus.Blueprint.AST.Expression.Type`)

  ## Examples

      %Literal{value: "Horus", type: :string}
      %Literal{value: true, type: :boolean}
      %Literal{value: 42, type: :integer}
  """

  alias Horus.Blueprint.AST.Expression.Type

  @type t :: %__MODULE__{
          value: any(),
          type: Type.type_atom()
        }

  @enforce_keys [:value, :type]
  defstruct [:value, :type]

  @doc """
  Deserializes a Literal from JSON (without "type" field).
  """
  def from_json(%{"value" => value, "value_type" => type}) do
    %__MODULE__{
      value: value,
      type: String.to_existing_atom(type)
    }
  end

  defimpl Horus.Blueprint.AST.Expression do
    def to_json(%Horus.Blueprint.AST.Expression.Literal{value: value, type: type}) do
      %{
        "type" => "literal",
        "value" => value,
        "value_type" => Atom.to_string(type)
      }
    end

    def extract_parameters(_), do: []
  end
end

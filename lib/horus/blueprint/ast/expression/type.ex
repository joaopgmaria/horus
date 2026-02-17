defmodule Horus.Blueprint.AST.Expression.Type do
  @moduledoc """
  Represents a data type for type checking operations.

  Used in type validation expressions like `${field} is a string`.

  ## Supported Types

  - `:string` - String type
  - `:integer` - Integer type
  - `:number` - Numeric type (integer or float)
  - `:boolean` - Boolean type
  - `:array` - Array/list type
  - `:object` - Object/map type

  ## Examples

      %Type{type: :string}
      %Type{type: :integer}
  """

  @type type_atom :: :string | :integer | :number | :boolean | :array | :object

  @type t :: %__MODULE__{
          type: type_atom()
        }

  @enforce_keys [:type]
  defstruct [:type]

  @doc """
  Deserializes a Type from JSON (without "type" field).
  """
  def from_json(%{"value" => value}) do
    %__MODULE__{type: String.to_existing_atom(value)}
  end

  defimpl Horus.Blueprint.AST.Expression do
    def to_json(%{type: type}) do
      %{
        "type" => "type",
        "value" => Atom.to_string(type)
      }
    end

    def extract_parameters(_), do: []
  end
end

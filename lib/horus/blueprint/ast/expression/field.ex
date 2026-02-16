defmodule Horus.Blueprint.AST.Expression.Field do
  @moduledoc """
  Represents a field path in the payload.

  Can be a placeholder (e.g., `${field}`) that will be bound at rule creation time,
  or a literal path (e.g., `/customer/email`) for direct field access.

  ## Fields

  - `path` - The field path string
  - `placeholder?` - Whether this is a parameter placeholder (default: true)

  ## Examples

      # Parameter placeholder
      %Field{path: "${field}", placeholder?: true}

      # Literal path (used after parameter binding)
      %Field{path: "/customer/email", placeholder?: false}
  """

  @type t :: %__MODULE__{
          path: String.t(),
          placeholder?: boolean()
        }

  @enforce_keys [:path]
  defstruct [:path, placeholder?: true]

  @doc """
  Deserializes a Field from JSON (without "type" field).
  """
  def from_json(%{"path" => path, "placeholder" => placeholder?}) do
    %__MODULE__{path: path, placeholder?: placeholder?}
  end

  defimpl Horus.Blueprint.AST.Expression do
    def to_json(%{path: path, placeholder?: placeholder?}) do
      %{
        "type" => "field",
        "path" => path,
        "placeholder" => placeholder?
      }
    end

    def extract_parameters(%{path: path, placeholder?: true}), do: [path]
    def extract_parameters(_), do: []
  end
end

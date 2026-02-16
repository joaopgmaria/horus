defmodule Horus.Blueprint.AST do
  @moduledoc """
  Abstract Syntax Tree definitions for blueprint DSL expressions.

  This module defines the expression types that make up the AST and provides
  serialization/deserialization functions for storing expressions in JSONB.

  ## Expression Types

  - `FieldExpression` - Represents a field path in the payload
  - `TypeExpression` - Represents a data type (string, integer, etc.)
  - `ComparisonExpression` - Represents a binary comparison operation
  - `ConditionalExpression` - Represents if/then conditional logic

  ## Protocol

  All expressions implement the `Expression` protocol which provides:
  - `to_json/1` - Serialize expression to JSONB-compatible map
  - `extract_parameters/1` - Extract all parameter placeholders

  ## Example

      iex> expr = %FieldExpression{path: "${field}", placeholder?: true}
      iex> Expression.to_json(expr)
      %{"type" => "field", "path" => "${field}", "placeholder" => true}

      iex> Expression.extract_parameters(expr)
      ["${field}"]
  """

  @doc """
  Deserializes a JSON map (from JSONB) back to an expression struct.

  Dispatches to the appropriate expression module based on the "type" field.

  ## Examples

      iex> Horus.Blueprint.AST.from_json(%{"type" => "field", "path" => "${field}", "placeholder" => true})
      %Horus.Blueprint.AST.FieldExpression{path: "${field}", placeholder?: true}

      iex> Horus.Blueprint.AST.from_json(%{"type" => "type", "value" => "string"})
      %Horus.Blueprint.AST.TypeExpression{type: :string}
  """
  @spec from_json(map()) :: Horus.Blueprint.AST.Expression.t()
  def from_json(%{"type" => "field"} = json) do
    Horus.Blueprint.AST.FieldExpression.from_json(Map.delete(json, "type"))
  end

  def from_json(%{"type" => "type"} = json) do
    Horus.Blueprint.AST.TypeExpression.from_json(Map.delete(json, "type"))
  end

  def from_json(%{"type" => "comparison"} = json) do
    Horus.Blueprint.AST.ComparisonExpression.from_json(Map.delete(json, "type"))
  end

  def from_json(%{"type" => "conditional"} = json) do
    Horus.Blueprint.AST.ConditionalExpression.from_json(Map.delete(json, "type"))
  end
end

defprotocol Horus.Blueprint.AST.Expression do
  @moduledoc """
  Protocol for all AST expression types.

  Provides common operations for expressions including serialization
  to JSON and parameter extraction.
  """

  @doc """
  Converts an expression to a JSON-serializable map for JSONB storage.
  """
  @spec to_json(t()) :: map()
  def to_json(expr)

  @doc """
  Extracts all parameter placeholders from this expression.
  Returns a list of parameter names (strings including ${} delimiters).
  """
  @spec extract_parameters(t()) :: [String.t()]
  def extract_parameters(expr)
end

defmodule Horus.Blueprint.AST.FieldExpression do
  @moduledoc """
  Represents a field path in the payload.

  Can be a placeholder (e.g., `${field}`) that will be bound at rule creation time,
  or a literal path (e.g., `/customer/email`) for direct field access.

  ## Fields

  - `path` - The field path string
  - `placeholder?` - Whether this is a parameter placeholder (default: true)

  ## Examples

      # Parameter placeholder
      %FieldExpression{path: "${field}", placeholder?: true}

      # Literal path (used after parameter binding)
      %FieldExpression{path: "/customer/email", placeholder?: false}
  """

  @type t :: %__MODULE__{
          path: String.t(),
          placeholder?: boolean()
        }

  @enforce_keys [:path]
  defstruct [:path, placeholder?: true]

  @doc """
  Deserializes a FieldExpression from JSON (without "type" field).
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

defmodule Horus.Blueprint.AST.TypeExpression do
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

      %TypeExpression{type: :string}
      %TypeExpression{type: :integer}
  """

  @type type_atom :: :string | :integer | :number | :boolean | :array | :object

  @type t :: %__MODULE__{
          type: type_atom()
        }

  @enforce_keys [:type]
  defstruct [:type]

  @doc """
  Deserializes a TypeExpression from JSON (without "type" field).
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

defmodule Horus.Blueprint.AST.ComparisonExpression do
  @moduledoc """
  Represents a binary comparison operation.

  Used for all comparison-based validations including type checks,
  equality checks, and presence checks.

  ## Operators

  - `:is_a` - Type checking: `${field} is a string`
  - `:equals` - Equality: `${field} equals ${value}` or `${field} is ${value}`
  - `:required` - Presence: `${field} is required` (right is nil)

  ## Examples

      # Type check
      %ComparisonExpression{
        operator: :is_a,
        left: %FieldExpression{path: "${field}"},
        right: %TypeExpression{type: :string}
      }

      # Presence check
      %ComparisonExpression{
        operator: :required,
        left: %FieldExpression{path: "${field}"},
        right: nil
      }

      # Equality
      %ComparisonExpression{
        operator: :equals,
        left: %FieldExpression{path: "${field}"},
        right: %FieldExpression{path: "${expected}"}
      }
  """

  @type operator :: :is_a | :equals | :required

  @type t :: %__MODULE__{
          operator: operator(),
          left: Horus.Blueprint.AST.Expression.t(),
          right: Horus.Blueprint.AST.Expression.t() | nil
        }

  @enforce_keys [:operator, :left]
  defstruct [:operator, :left, :right]

  @doc """
  Deserializes a ComparisonExpression from JSON (without "type" field).
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

defmodule Horus.Blueprint.AST.ConditionalExpression do
  @moduledoc """
  Represents if/then conditional logic.

  Used for conditional validation rules where one validation depends on another.

  ## Fields

  - `condition` - The condition expression (must evaluate to boolean)
  - `then_expr` - The expression to evaluate if condition is true

  ## Examples

      # "if ${country} is a string then ${postal_code} is required"
      %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${country}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :required,
          left: %FieldExpression{path: "${postal_code}"},
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
  Deserializes a ConditionalExpression from JSON (without "type" field).
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

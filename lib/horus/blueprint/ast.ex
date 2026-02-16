defmodule Horus.Blueprint.AST do
  @moduledoc """
  Abstract Syntax Tree definitions for blueprint DSL expressions.

  This module provides serialization/deserialization functions for storing
  expressions in JSONB and acts as the main entry point for AST operations.

  ## Expression Types

  - `Field` - Represents a field path in the payload
  - `Type` - Represents a data type (string, integer, etc.)
  - `Comparison` - Represents a binary comparison operation
  - `Conditional` - Represents if/then conditional logic

  ## Protocol

  All expressions implement the `Expression` protocol which provides:
  - `to_json/1` - Serialize expression to JSONB-compatible map
  - `extract_parameters/1` - Extract all parameter placeholders

  ## Example

      iex> expr = %Field{path: "${field}", placeholder?: true}
      iex> Expression.to_json(expr)
      %{"type" => "field", "path" => "${field}", "placeholder" => true}

      iex> Expression.extract_parameters(expr)
      ["${field}"]
  """

  alias Horus.Blueprint.AST.Expression.Comparison
  alias Horus.Blueprint.AST.Expression.Conditional
  alias Horus.Blueprint.AST.Expression.Field
  alias Horus.Blueprint.AST.Expression.Type

  @doc """
  Deserializes a JSON map (from JSONB) back to an expression struct.

  Dispatches to the appropriate expression module based on the "type" field.

  ## Examples

      iex> Horus.Blueprint.AST.from_json(%{"type" => "field", "path" => "${field}", "placeholder" => true})
      %Horus.Blueprint.AST.Expression.Field{path: "${field}", placeholder?: true}

      iex> Horus.Blueprint.AST.from_json(%{"type" => "type", "value" => "string"})
      %Horus.Blueprint.AST.Expression.Type{type: :string}
  """
  @spec from_json(map()) :: Horus.Blueprint.AST.Expression.t()
  def from_json(%{"type" => "field"} = json) do
    Field.from_json(Map.delete(json, "type"))
  end

  def from_json(%{"type" => "type"} = json) do
    Type.from_json(Map.delete(json, "type"))
  end

  def from_json(%{"type" => "comparison"} = json) do
    Comparison.from_json(Map.delete(json, "type"))
  end

  def from_json(%{"type" => "conditional"} = json) do
    Conditional.from_json(Map.delete(json, "type"))
  end
end

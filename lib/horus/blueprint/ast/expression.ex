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

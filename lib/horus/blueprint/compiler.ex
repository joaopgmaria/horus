defmodule Horus.Blueprint.Compiler do
  @moduledoc """
  High-level API for compiling blueprint DSL to AST.

  This module orchestrates the parsing pipeline and parameter extraction,
  providing a simple interface for converting natural language validation
  rules into executable Abstract Syntax Trees.

  ## Examples

      iex> compile("${field} is a string")
      {:ok, %{
        ast: %ComparisonExpression{...},
        parameters: [%{name: "${field}", occurrences: 1, ...}],
        json: %{"type" => "comparison", ...}
      }}

      iex> compile("if ${country} is a string then ${postal_code} is required")
      {:ok, %{
        ast: %ConditionalExpression{...},
        parameters: [
          %{name: "${country}", occurrences: 1, ...},
          %{name: "${postal_code}", occurrences: 1, ...}
        ],
        json: %{"type" => "conditional", ...}
      }}
  """

  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.Parser

  @type compile_result :: {:ok, compile_info()} | {:error, compile_error()}

  @type compile_info :: %{
          ast: Expression.t(),
          parameters: [parameter_info()],
          json: map()
        }

  @type parameter_info :: %{
          name: String.t(),
          occurrences: pos_integer()
        }

  @type compile_error :: %{
          message: String.t(),
          line: non_neg_integer() | nil,
          column: non_neg_integer() | nil
        }

  @doc """
  Compiles a DSL string into an AST and extracts parameter metadata.

  Returns a map containing:
  - `ast`: The parsed Abstract Syntax Tree
  - `parameters`: List of parameter metadata (name, occurrence count)
  - `json`: JSONB-serializable representation of the AST

  ## Examples

      iex> compile("${field} is a string")
      {:ok, %{
        ast: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${field}"},
          right: %TypeExpression{type: :string}
        },
        parameters: [%{name: "${field}", occurrences: 1}],
        json: %{
          "type" => "comparison",
          "operator" => "is_a",
          "left" => %{"type" => "field", "path" => "${field}", "placeholder" => true},
          "right" => %{"type" => "type", "value" => "string"}
        }
      }}

      iex> compile("invalid syntax")
      {:error, %{message: "...", line: 1, column: 1}}
  """
  @spec compile(String.t()) :: compile_result()
  def compile(dsl) when is_binary(dsl) do
    with {:ok, ast} <- Parser.parse_dsl(dsl),
         parameters <- extract_parameters(ast),
         json <- Expression.to_json(ast) do
      {:ok, %{ast: ast, parameters: parameters, json: json}}
    end
  end

  @doc """
  Extracts parameter information from an AST.

  Returns a list of parameters with metadata about their usage including:
  - `name`: The parameter name (e.g., "${field}")
  - `occurrences`: Number of times the parameter appears in the expression

  ## Examples

      iex> ast = %ComparisonExpression{
      ...>   operator: :equals,
      ...>   left: %FieldExpression{path: "${field}"},
      ...>   right: %FieldExpression{path: "${field}"}
      ...> }
      iex> extract_parameters(ast)
      [%{name: "${field}", occurrences: 2}]

      iex> ast = %ConditionalExpression{
      ...>   condition: %ComparisonExpression{
      ...>     operator: :is_a,
      ...>     left: %FieldExpression{path: "${country}"},
      ...>     right: %TypeExpression{type: :string}
      ...>   },
      ...>   then_expr: %ComparisonExpression{
      ...>     operator: :required,
      ...>     left: %FieldExpression{path: "${postal_code}"},
      ...>     right: nil
      ...>   }
      ...> }
      iex> extract_parameters(ast)
      [%{name: "${country}", occurrences: 1}, %{name: "${postal_code}", occurrences: 1}]
  """
  @spec extract_parameters(Expression.t()) :: [parameter_info()]
  def extract_parameters(ast) do
    ast
    |> Expression.extract_parameters()
    |> group_parameters()
  end

  # Group parameters by name and count occurrences
  defp group_parameters(param_list) do
    param_list
    |> Enum.frequencies()
    |> Enum.map(fn {name, count} ->
      %{name: name, occurrences: count}
    end)
    |> Enum.sort_by(& &1.name)
  end
end

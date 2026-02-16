defmodule Horus.Blueprint.CompilerTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.Compiler

  alias Horus.Blueprint.AST.{
    ComparisonExpression,
    ConditionalExpression,
    FieldExpression,
    TypeExpression
  }

  describe "compile/1 - successful compilation" do
    test "compiles simple type check and returns all components" do
      {:ok, result} = Compiler.compile("${field} is a string")

      assert %{ast: ast, parameters: params, json: json} = result

      # Verify AST structure
      assert %ComparisonExpression{
               operator: :is_a,
               left: %FieldExpression{path: "${field}"},
               right: %TypeExpression{type: :string}
             } = ast

      # Verify parameters
      assert [%{name: "${field}", occurrences: 1}] = params

      # Verify JSON structure
      assert %{
               "type" => "comparison",
               "operator" => "is_a",
               "left" => %{"type" => "field", "path" => "${field}", "placeholder" => true},
               "right" => %{"type" => "type", "value" => "string"}
             } = json
    end

    test "compiles required check" do
      {:ok, result} = Compiler.compile("${field} is required")

      assert %{ast: ast, parameters: params, json: json} = result
      assert %ComparisonExpression{operator: :presence} = ast
      assert [%{name: "${field}", occurrences: 1}] = params
      assert %{"type" => "comparison", "operator" => "presence"} = json
    end

    test "compiles equality check" do
      {:ok, result} = Compiler.compile("${field} equals ${expected}")

      assert %{ast: ast, parameters: params} = result
      assert %ComparisonExpression{operator: :equals} = ast
      assert length(params) == 2

      param_names = Enum.map(params, & &1.name) |> Enum.sort()
      assert param_names == ["${expected}", "${field}"]
    end

    test "compiles conditional expression" do
      {:ok, result} =
        Compiler.compile("if ${country} is a string then ${postal_code} is required")

      assert %{ast: ast, parameters: params} = result

      assert %ConditionalExpression{
               condition: %ComparisonExpression{operator: :is_a},
               then_expr: %ComparisonExpression{operator: :presence}
             } = ast

      assert length(params) == 2
      param_names = Enum.map(params, & &1.name) |> Enum.sort()
      assert param_names == ["${country}", "${postal_code}"]
    end
  end

  describe "compile/1 - parameter extraction" do
    test "extracts single parameter" do
      {:ok, %{parameters: params}} = Compiler.compile("${field} is required")

      assert [%{name: "${field}", occurrences: 1}] = params
    end

    test "extracts multiple distinct parameters" do
      {:ok, %{parameters: params}} = Compiler.compile("${field} equals ${expected}")

      assert length(params) == 2
      assert Enum.all?(params, &(&1.occurrences == 1))

      param_names = Enum.map(params, & &1.name) |> Enum.sort()
      assert param_names == ["${expected}", "${field}"]
    end

    test "counts multiple occurrences of same parameter" do
      {:ok, %{parameters: params}} =
        Compiler.compile("if ${field} is a string then ${field} is required")

      assert [%{name: "${field}", occurrences: 2}] = params
    end

    test "extracts parameters from complex conditional" do
      {:ok, %{parameters: params}} =
        Compiler.compile("if ${status} equals ${expected_status} then ${amount} is required")

      assert length(params) == 3

      param_map = Map.new(params, fn p -> {p.name, p.occurrences} end)

      assert param_map == %{
               "${status}" => 1,
               "${expected_status}" => 1,
               "${amount}" => 1
             }
    end

    test "parameters are sorted alphabetically" do
      {:ok, %{parameters: params}} = Compiler.compile("${zebra} equals ${apple}")

      param_names = Enum.map(params, & &1.name)
      assert param_names == ["${apple}", "${zebra}"]
    end
  end

  describe "compile/1 - JSON serialization" do
    test "JSON is valid and serializable" do
      {:ok, %{json: json}} = Compiler.compile("${field} is a string")

      # Should be a map with string keys
      assert is_map(json)
      assert Map.has_key?(json, "type")

      # Should be JSON-encodable
      assert {:ok, _json_string} = Jason.encode(json)
    end

    test "JSON matches AST structure" do
      {:ok, %{ast: ast, json: json}} = Compiler.compile("${field} equals ${value}")

      # JSON should have the same operator
      assert json["operator"] == "equals"

      # JSON should have left and right
      assert is_map(json["left"])
      assert is_map(json["right"])

      # Verify round-trip through JSON
      deserialized = Horus.Blueprint.AST.from_json(json)
      assert deserialized == ast
    end

    test "JSON for conditional includes condition and then" do
      {:ok, %{json: json}} =
        Compiler.compile("if ${country} is a string then ${postal_code} is required")

      assert json["type"] == "conditional"
      assert is_map(json["condition"])
      assert is_map(json["then"])

      # Verify nested structure
      assert json["condition"]["type"] == "comparison"
      assert json["then"]["type"] == "comparison"
    end
  end

  describe "compile/1 - error handling" do
    test "returns error for invalid syntax" do
      assert {:error, %{message: _message}} = Compiler.compile("invalid syntax")
    end

    test "returns error for empty string" do
      assert {:error, %{message: message}} = Compiler.compile("")
      assert message =~ "empty string"
    end

    test "returns error for malformed placeholder" do
      assert {:error, %{message: _}} = Compiler.compile(~s/${field is a string/)
    end

    test "returns error for incomplete expression" do
      assert {:error, %{message: _}} = Compiler.compile("${field} is")
    end

    test "error includes line and column information" do
      assert {:error, %{line: _line, column: _col}} = Compiler.compile("invalid")
      # Line and column are present in the error map
    end
  end

  describe "extract_parameters/1" do
    test "extracts from simple expression" do
      ast = %ComparisonExpression{
        operator: :presence,
        left: %FieldExpression{path: "${field}"},
        right: nil
      }

      params = Compiler.extract_parameters(ast)
      assert [%{name: "${field}", occurrences: 1}] = params
    end

    test "extracts from expression with multiple parameters" do
      ast = %ComparisonExpression{
        operator: :equals,
        left: %FieldExpression{path: "${field}"},
        right: %FieldExpression{path: "${value}"}
      }

      params = Compiler.extract_parameters(ast)
      assert length(params) == 2

      param_names = Enum.map(params, & &1.name) |> Enum.sort()
      assert param_names == ["${field}", "${value}"]
    end

    test "counts duplicate parameters" do
      ast = %ComparisonExpression{
        operator: :equals,
        left: %FieldExpression{path: "${field}"},
        right: %FieldExpression{path: "${field}"}
      }

      params = Compiler.extract_parameters(ast)
      assert [%{name: "${field}", occurrences: 2}] = params
    end

    test "extracts from conditional expression" do
      ast = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${country}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${postal_code}"},
          right: nil
        }
      }

      params = Compiler.extract_parameters(ast)
      assert length(params) == 2

      param_map = Map.new(params, fn p -> {p.name, p.occurrences} end)
      assert param_map == %{"${country}" => 1, "${postal_code}" => 1}
    end

    test "handles parameters appearing in multiple branches" do
      ast = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${field}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${field}"},
          right: nil
        }
      }

      params = Compiler.extract_parameters(ast)
      assert [%{name: "${field}", occurrences: 2}] = params
    end
  end

  describe "integration - full pipeline" do
    test "can compile, serialize, and deserialize" do
      dsl = "if ${country} is a string then ${postal_code} is required"
      {:ok, %{ast: original_ast, json: json}} = Compiler.compile(dsl)

      # Serialize to JSON
      {:ok, json_string} = Jason.encode(json)

      # Deserialize back
      {:ok, decoded_json} = Jason.decode(json_string)
      deserialized_ast = Horus.Blueprint.AST.from_json(decoded_json)

      # Should match original
      assert deserialized_ast == original_ast
    end

    test "parameter extraction is consistent across compilation" do
      dsl = "if ${status} equals ${expected} then ${amount} is required"

      # Compile twice
      {:ok, result1} = Compiler.compile(dsl)
      {:ok, result2} = Compiler.compile(dsl)

      # Parameters should be identical
      assert result1.parameters == result2.parameters
    end

    test "supports all MVP operators" do
      test_cases = [
        {"${field} is a string", :is_a},
        {"${field} is required", :presence},
        {"${field} equals ${value}", :equals},
        {"${field} is ${value}", :equals},
        {"if ${field} is a string then ${other} is required", :conditional}
      ]

      for {dsl, expected_type} <- test_cases do
        {:ok, %{ast: ast}} = Compiler.compile(dsl)

        case expected_type do
          :conditional -> assert %ConditionalExpression{} = ast
          operator -> assert %ComparisonExpression{operator: ^operator} = ast
        end
      end
    end
  end
end

defmodule Horus.Blueprint.CompilerTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST.{ComparisonExpression, FieldExpression}
  alias Horus.Blueprint.Compiler

  describe "compile/1 - successful compilation" do
    test "compiles presence check and returns all components" do
      {:ok, result} = Compiler.compile("${field} exists")

      # Check AST
      assert %ComparisonExpression{
               operator: :presence,
               left: %FieldExpression{path: "${field}"},
               right: nil
             } = result.ast

      # Check parameters
      assert [%{name: "${field}", occurrences: 1}] = result.parameters

      # Check JSON
      assert %{"type" => "comparison", "operator" => "presence"} = result.json
    end

    test "compiles presence check with 'is required' form" do
      {:ok, result} = Compiler.compile("${email} is required")

      assert %ComparisonExpression{operator: :presence} = result.ast
      assert [%{name: "${email}", occurrences: 1}] = result.parameters
    end

    test "compiles presence check with 'must be present' form" do
      {:ok, result} = Compiler.compile("${email} must be present")

      assert %ComparisonExpression{operator: :presence} = result.ast
      assert [%{name: "${email}", occurrences: 1}] = result.parameters
    end
  end

  describe "compile/1 - parameter extraction" do
    test "extracts single parameter" do
      {:ok, result} = Compiler.compile("${field} exists")
      assert [%{name: "${field}", occurrences: 1}] = result.parameters
    end

    test "extracts parameter with underscores and numbers" do
      {:ok, result} = Compiler.compile("${user_id_123} exists")
      assert [%{name: "${user_id_123}", occurrences: 1}] = result.parameters
    end

    test "parameter includes occurrence count" do
      {:ok, result} = Compiler.compile("${field} exists")
      [param] = result.parameters

      assert param.name == "${field}"
      assert param.occurrences == 1
    end
  end

  describe "compile/1 - JSON serialization" do
    test "JSON is valid and serializable" do
      {:ok, result} = Compiler.compile("${field} exists")

      # Ensure JSON can be encoded
      assert {:ok, _} = Jason.encode(result.json)
    end

    test "JSON matches AST structure" do
      {:ok, result} = Compiler.compile("${field} exists")

      assert result.json == %{
               "type" => "comparison",
               "operator" => "presence",
               "left" => %{"type" => "field", "path" => "${field}", "placeholder" => true},
               "right" => nil
             }
    end
  end

  describe "compile/1 - error handling" do
    test "returns error for invalid syntax" do
      assert {:error, %{message: _}} = Compiler.compile("not valid syntax")
    end

    test "returns error for empty string" do
      assert {:error, %{message: message}} = Compiler.compile("")
      assert message =~ "empty string"
    end

    test "returns error for malformed placeholder" do
      assert {:error, %{message: _}} = Compiler.compile("${field exists")
    end

    test "returns error for incomplete expression" do
      assert {:error, %{message: _}} = Compiler.compile("${field}")
    end

    test "error includes line and column information" do
      assert {:error, error} = Compiler.compile("invalid")
      assert Map.has_key?(error, :line)
      assert Map.has_key?(error, :column)
    end
  end

  describe "extract_parameters/1" do
    test "extracts from simple presence expression" do
      {:ok, result} = Compiler.compile("${field} exists")
      params = Compiler.extract_parameters(result.ast)

      assert length(params) == 1
      assert [%{name: "${field}", occurrences: 1}] = params
    end

    test "includes occurrence count" do
      {:ok, result} = Compiler.compile("${email} exists")
      [param] = Compiler.extract_parameters(result.ast)

      assert param.name == "${email}"
      assert param.occurrences == 1
    end
  end

  describe "integration - full pipeline" do
    test "can compile, serialize, and deserialize" do
      dsl = "${field} exists"
      {:ok, result} = Compiler.compile(dsl)

      # Verify JSON serialization
      assert {:ok, json_string} = Jason.encode(result.json)

      # Verify deserialization
      assert {:ok, decoded_json} = Jason.decode(json_string)

      # Verify structure preserved
      assert decoded_json["type"] == "comparison"
      assert decoded_json["operator"] == "presence"
    end

    test "parameter extraction is consistent across compilation" do
      dsl = "${customer_email} exists"

      # Compile twice
      {:ok, result1} = Compiler.compile(dsl)
      {:ok, result2} = Compiler.compile(dsl)

      # Parameters should be identical
      assert result1.parameters == result2.parameters
      assert [%{name: "${customer_email}", occurrences: 1}] = result1.parameters
    end
  end
end

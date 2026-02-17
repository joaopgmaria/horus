defmodule Horus.Blueprint.CompilerTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST.Expression.{Comparison, Field}
  alias Horus.Blueprint.Compiler

  describe "compile/1 - successful compilation" do
    test "compiles presence check and returns all components" do
      {:ok, result} = Compiler.compile("${field} exists")

      # Check AST
      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${field}"},
               right: nil
             } = result.ast

      # Check parameters
      assert [%{name: "${field}", occurrences: 1}] = result.parameters

      # Check JSON
      assert %{"type" => "comparison", "operator" => "presence"} = result.json
    end

    test "compiles presence check with 'is required' form" do
      {:ok, result} = Compiler.compile("${email} is required")

      assert %Comparison{operator: :presence} = result.ast
      assert [%{name: "${email}", occurrences: 1}] = result.parameters
    end

    test "compiles presence check with 'must be present' form" do
      {:ok, result} = Compiler.compile("${email} must be present")

      assert %Comparison{operator: :presence} = result.ast
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

    test "compiles plain field expression" do
      {:ok, result} = Compiler.compile("${field}")
      assert %Field{path: "${field}"} = result.ast
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

  describe "compile/1 - literals and boolean logic" do
    alias Horus.Blueprint.AST.Expression.{Boolean, Literal}

    test "compiles integer literal" do
      {:ok, result} = Compiler.compile("42")
      assert %Literal{value: 42, type: :integer} = result.ast
      assert result.json["type"] == "literal"
      assert result.json["value"] == 42
    end

    test "compiles boolean literal" do
      {:ok, result} = Compiler.compile("true")
      assert %Literal{value: true, type: :boolean} = result.ast
      assert result.json["value"] == true
    end

    test "compiles boolean NOT logic" do
      {:ok, result} = Compiler.compile("not true")
      assert %Boolean{operator: :not, left: %Literal{value: true}} = result.ast
      assert result.json["type"] == "boolean"
      assert result.json["operator"] == "not"
    end

    test "compiles boolean AND logic" do
      # Note: This might require more complex parsing if we want to support multiple expressions
      {:ok, result} = Compiler.compile("true and false")

      assert %Boolean{operator: :and, left: %Literal{value: true}, right: %Literal{value: false}} =
               result.ast
    end

    test "compiles string literal (double quotes)" do
      {:ok, result} = Compiler.compile("\"hello\"")
      assert %Literal{value: "hello", type: :string} = result.ast
    end

    test "compiles string literal (single quotes)" do
      {:ok, result} = Compiler.compile("'world'")
      assert %Literal{value: "world", type: :string} = result.ast
    end

    test "compiles atom literal" do
      {:ok, result} = Compiler.compile(":horus")
      assert %Literal{value: :horus, type: :atom} = result.ast
    end

    test "compiles grouped expression with parentheses" do
      {:ok, result} = Compiler.compile("(true or false) and true")
      assert %Boolean{operator: :and, left: %Boolean{operator: :or}} = result.ast
    end

    test "respects operator precedence (NOT > AND > OR)" do
      {:ok, result} = Compiler.compile("true or not false and false")
      # This should be: true or ((not false) and false)
      assert %Boolean{operator: :or, left: %Literal{value: true}, right: %Boolean{operator: :and}} =
               result.ast
    end
  end

  describe "compile/1 - regex match" do
    alias Horus.Blueprint.AST.Expression.{Comparison, Field, Literal}

    test "compiles regex literal" do
      {:ok, result} = Compiler.compile("/\\d+/")

      assert %Literal{value: "\\d+", type: :regex} = result.ast
      assert result.json["type"] == "literal"
      assert result.json["value"] == "\\d+"
    end

    test "compiles match operator when using regex" do
      {:ok, result} = Compiler.compile("${field} matches /\\d+/")

      assert %Comparison{
               operator: :match,
               left: %Field{path: "${field}", placeholder?: true},
               right: %Literal{value: "\\d+", type: :regex}
             } = result.ast

      assert result.json["type"] == "comparison"
      assert result.json["operator"] == "match"
    end

    test "compiles match operator with regex placeholder" do
      {:ok, result} = Compiler.compile("${field} matches ${regex}")

      assert %Comparison{
               operator: :match,
               left: %Field{path: "${field}", placeholder?: true},
               right: %Field{path: "${regex}", placeholder?: true}
             } = result.ast

      assert result.json["type"] == "comparison"
      assert result.json["operator"] == "match"
    end
  end
end

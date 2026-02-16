defmodule Horus.Blueprint.ParserTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.Parser

  alias Horus.Blueprint.AST.{
    ComparisonExpression,
    ConditionalExpression,
    FieldExpression,
    TypeExpression
  }

  describe "parse_dsl/1 - type checking (is a)" do
    test "parses '${field} is a string'" do
      {:ok, ast} = Parser.parse_dsl("${field} is a string")

      assert %ComparisonExpression{
               operator: :is_a,
               left: %FieldExpression{path: "${field}", placeholder?: true},
               right: %TypeExpression{type: :string}
             } = ast
    end

    test "parses all supported types" do
      types = [:string, :integer, :number, :boolean, :array, :object]

      for type <- types do
        {:ok, ast} = Parser.parse_dsl("${field} is a #{type}")
        assert %ComparisonExpression{operator: :is_a, right: %TypeExpression{type: ^type}} = ast
      end
    end

    test "handles different placeholder names" do
      placeholders = ["field", "customer_name", "user_id_123", "a", "field_name_with_numbers_456"]

      for placeholder <- placeholders do
        {:ok, ast} = Parser.parse_dsl("${#{placeholder}} is a string")
        expected_path = "${#{placeholder}}"
        assert %ComparisonExpression{left: %FieldExpression{path: ^expected_path}} = ast
      end
    end

    test "handles whitespace variations" do
      variations = [
        "${field} is a string",
        "${field}  is  a  string",
        "${field}   is   a   string",
        "  ${field} is a string  ",
        "\t${field}\tis\ta\tstring\t"
      ]

      for dsl <- variations do
        assert {:ok, %ComparisonExpression{operator: :is_a}} = Parser.parse_dsl(dsl)
      end
    end
  end

  describe "parse_dsl/1 - required operator" do
    test "parses '${field} is required'" do
      {:ok, ast} = Parser.parse_dsl("${field} is required")

      assert %ComparisonExpression{
               operator: :presence,
               left: %FieldExpression{path: "${field}", placeholder?: true},
               right: nil
             } = ast
    end

    test "handles different placeholders" do
      {:ok, ast} = Parser.parse_dsl("${customer_email} is required")

      assert %ComparisonExpression{
               operator: :presence,
               left: %FieldExpression{path: "${customer_email}"}
             } = ast
    end

    test "handles whitespace" do
      variations = [
        "${field} is required",
        "${field}  is  required",
        "  ${field} is required  "
      ]

      for dsl <- variations do
        assert {:ok, %ComparisonExpression{operator: :presence}} = Parser.parse_dsl(dsl)
      end
    end
  end

  describe "parse_dsl/1 - equality operator" do
    test "parses '${field} equals ${value}'" do
      {:ok, ast} = Parser.parse_dsl("${field} equals ${value}")

      assert %ComparisonExpression{
               operator: :equals,
               left: %FieldExpression{path: "${field}", placeholder?: true},
               right: %FieldExpression{path: "${value}", placeholder?: true}
             } = ast
    end

    test "parses '${field} is ${value}' (is as alias for equals)" do
      {:ok, ast} = Parser.parse_dsl("${field} is ${value}")

      assert %ComparisonExpression{
               operator: :equals,
               left: %FieldExpression{path: "${field}"},
               right: %FieldExpression{path: "${value}"}
             } = ast
    end

    test "handles different placeholder combinations" do
      {:ok, ast} = Parser.parse_dsl("${status} equals ${expected_status}")

      assert %ComparisonExpression{
               left: %FieldExpression{path: "${status}"},
               right: %FieldExpression{path: "${expected_status}"}
             } = ast
    end

    test "handles whitespace" do
      variations = [
        "${field} equals ${value}",
        "${field}  equals  ${value}",
        "  ${field} equals ${value}  ",
        "${field} is ${value}",
        "${field}  is  ${value}"
      ]

      for dsl <- variations do
        assert {:ok, %ComparisonExpression{operator: :equals}} = Parser.parse_dsl(dsl)
      end
    end
  end

  describe "parse_dsl/1 - conditional expressions" do
    test "parses 'if ${country} is a string then ${postal_code} is required'" do
      {:ok, ast} = Parser.parse_dsl("if ${country} is a string then ${postal_code} is required")

      assert %ConditionalExpression{
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
             } = ast
    end

    test "parses conditional with equality in condition" do
      {:ok, ast} =
        Parser.parse_dsl("if ${status} equals ${expected_status} then ${amount} is required")

      assert %ConditionalExpression{
               condition: %ComparisonExpression{
                 operator: :equals,
                 left: %FieldExpression{path: "${status}"},
                 right: %FieldExpression{path: "${expected_status}"}
               },
               then_expr: %ComparisonExpression{
                 operator: :presence
               }
             } = ast
    end

    test "parses conditional with type check in then branch" do
      {:ok, ast} = Parser.parse_dsl("if ${country} is required then ${postal_code} is a string")

      assert %ConditionalExpression{
               condition: %ComparisonExpression{operator: :presence},
               then_expr: %ComparisonExpression{operator: :is_a}
             } = ast
    end

    test "parses conditional with equality in both branches" do
      {:ok, ast} =
        Parser.parse_dsl("if ${field1} equals ${value1} then ${field2} equals ${value2}")

      assert %ConditionalExpression{
               condition: %ComparisonExpression{operator: :equals},
               then_expr: %ComparisonExpression{operator: :equals}
             } = ast
    end

    test "handles whitespace in conditionals" do
      variations = [
        "if ${country} is a string then ${postal_code} is required",
        "if  ${country}  is  a  string  then  ${postal_code}  is  required",
        "  if ${country} is a string then ${postal_code} is required  "
      ]

      for dsl <- variations do
        assert {:ok, %ConditionalExpression{}} = Parser.parse_dsl(dsl)
      end
    end
  end

  describe "parse_dsl/1 - error handling" do
    test "returns error for empty string" do
      assert {:error, %{message: message}} = Parser.parse_dsl("")
      assert message =~ "empty string"
    end

    test "returns error for only whitespace" do
      assert {:error, %{message: message}} = Parser.parse_dsl("   ")
      assert message =~ "empty string"
    end

    test "returns error for invalid syntax" do
      assert {:error, %{message: _message}} = Parser.parse_dsl("invalid syntax")
    end

    test "returns error for incomplete expression" do
      assert {:error, %{message: _message}} = Parser.parse_dsl("${field} is")
    end

    test "returns error for malformed placeholder" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${} is a string")
    end

    test "returns error for missing closing brace" do
      assert {:error, %{message: _}} = Parser.parse_dsl(~s/${field is a string/)
    end

    test "returns error for unknown operator" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${field} contains ${value}")
    end

    test "returns error for unknown type" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${field} is a unknown_type")
    end

    test "returns error for incomplete conditional" do
      assert {:error, %{message: _}} = Parser.parse_dsl("if ${field} is a string")
    end

    test "returns error for conditional without then" do
      assert {:error, %{message: _}} =
               Parser.parse_dsl("if ${field} is a string ${other} is required")
    end
  end

  describe "parse_dsl/1 - edge cases" do
    test "handles placeholder with underscores" do
      {:ok, ast} = Parser.parse_dsl("${field_name} is required")
      assert ast.left.path == "${field_name}"
    end

    test "handles placeholder with numbers" do
      {:ok, ast} = Parser.parse_dsl("${field123} is required")
      assert ast.left.path == "${field123}"
    end

    test "handles placeholder with underscores and numbers" do
      {:ok, ast} = Parser.parse_dsl("${field_name_123} is required")
      assert ast.left.path == "${field_name_123}"
    end

    test "does not allow uppercase in placeholders" do
      assert {:error, _} = Parser.parse_dsl("${Field} is required")
    end

    test "does not allow hyphens in placeholders" do
      assert {:error, _} = Parser.parse_dsl("${field-name} is required")
    end

    test "does not allow spaces in placeholders" do
      assert {:error, _} = Parser.parse_dsl("${field name} is required")
    end
  end
end

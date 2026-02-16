defmodule Horus.Blueprint.ParserTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST.Expression.{Comparison, Field}
  alias Horus.Blueprint.Parser

  describe "parse_dsl/1 - integration with Registry" do
    test "successfully parses Presence operator" do
      {:ok, ast} = Parser.parse_dsl("${field} exists")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${field}", placeholder?: true},
               right: nil
             } = ast
    end

    test "delegates to Registry for operator-specific parsing" do
      # Verify parser correctly routes to Registry
      {:ok, ast} = Parser.parse_dsl("${email} is required")
      assert %Comparison{operator: :presence} = ast
    end

    test "handles whitespace correctly" do
      variations = [
        "${field} exists",
        "${field}  exists",
        "  ${field} exists  ",
        "\t${field}\texists\t"
      ]

      for dsl <- variations do
        assert {:ok, %Comparison{operator: :presence}} = Parser.parse_dsl(dsl)
      end
    end

    test "handles various placeholder names" do
      placeholders = ["field", "customer_name", "user_id_123", "a", "field_name_with_numbers_456"]

      for placeholder <- placeholders do
        {:ok, ast} = Parser.parse_dsl("${#{placeholder}} exists")
        expected_path = "${#{placeholder}}"
        assert %Comparison{left: %Field{path: ^expected_path}} = ast
      end
    end
  end

  describe "parse_dsl/1 - error handling" do
    test "returns error for empty string" do
      assert {:error, %{message: message}} = Parser.parse_dsl("")
      assert message =~ "empty string"
    end

    test "returns error for unknown operator" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${field} unknown_operator")
    end

    test "returns error for malformed placeholder - missing closing brace" do
      assert {:error, %{message: message}} = Parser.parse_dsl("${field")
      assert message =~ "malformed placeholder"
    end

    test "returns error for malformed placeholder - missing opening brace" do
      assert {:error, %{message: _}} = Parser.parse_dsl("field} exists")
    end

    test "returns error for empty placeholder" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${} exists")
    end

    test "returns error for placeholder with invalid characters" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${field-name} exists")
    end

    test "returns error for placeholder with uppercase letters" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${Field} exists")
    end

    test "returns error for placeholder with spaces" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${field name} exists")
    end

    test "returns error for completely invalid syntax" do
      assert {:error, %{message: _}} = Parser.parse_dsl("this is not valid")
    end

    test "returns error for unexpected characters after valid expression" do
      assert {:error, %{message: message}} = Parser.parse_dsl("${field} exists extra")
      assert message =~ "Unexpected input"
    end
  end
end

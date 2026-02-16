defmodule Horus.Blueprint.AST.Operator.PresenceTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST.Expression.{Comparison, Field}
  alias Horus.Blueprint.AST.Operator.Presence
  alias Horus.Blueprint.Parser

  describe "operator metadata" do
    test "has correct operator name" do
      assert Presence.operator_name() == :presence
    end

    test "has correct operator forms" do
      assert Presence.operator_forms() == [
               "exists",
               "must exist",
               "should exist",
               "is required",
               "is present",
               "must be present",
               "should be present",
               "must be filled in",
               "should be filled in"
             ]
    end
  end

  describe "tokens_to_ast/1" do
    test "builds correct AST for simple field" do
      tokens = [{:presence, [{:placeholder, "email"}, {:operator, :presence}]}]

      ast = Presence.tokens_to_ast(tokens)

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "builds correct AST for field with underscore" do
      tokens = [{:presence, [{:placeholder, "first_name"}, {:operator, :presence}]}]

      ast = Presence.tokens_to_ast(tokens)

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${first_name}", placeholder?: true},
               right: nil
             } = ast
    end

    test "builds correct AST for field with numbers" do
      tokens = [{:presence, [{:placeholder, "field123"}, {:operator, :presence}]}]

      ast = Presence.tokens_to_ast(tokens)

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${field123}", placeholder?: true},
               right: nil
             } = ast
    end
  end

  describe "integration with parser" do
    test "parses main form 'exists'" do
      {:ok, ast} = Parser.parse_dsl("${email} exists")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses form 'must exist'" do
      {:ok, ast} = Parser.parse_dsl("${email} must exist")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses form 'should exist'" do
      {:ok, ast} = Parser.parse_dsl("${email} should exist")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'is required'" do
      {:ok, ast} = Parser.parse_dsl("${email} is required")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'is present'" do
      {:ok, ast} = Parser.parse_dsl("${email} is present")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'must be present'" do
      {:ok, ast} = Parser.parse_dsl("${email} must be present")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'should be present'" do
      {:ok, ast} = Parser.parse_dsl("${email} should be present")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'must be filled in'" do
      {:ok, ast} = Parser.parse_dsl("${email} must be filled in")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'should be filled in'" do
      {:ok, ast} = Parser.parse_dsl("${email} should be filled in")

      assert %Comparison{
               operator: :presence,
               left: %Field{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end
  end

  describe "validation - only placeholders allowed" do
    test "rejects direct path syntax" do
      assert {:error, %{message: _}} = Parser.parse_dsl("/customer/email exists")
    end

    test "rejects path without placeholder syntax" do
      assert {:error, %{message: _}} = Parser.parse_dsl("email exists")
    end

    test "rejects malformed placeholder - missing closing brace" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${email exists")
    end

    test "rejects malformed placeholder - missing opening brace" do
      assert {:error, %{message: _}} = Parser.parse_dsl("email} exists")
    end

    test "rejects empty placeholder" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${} exists")
    end

    test "rejects placeholder with invalid characters" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${email-address} exists")
    end

    test "rejects placeholder with uppercase letters" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${Email} exists")
    end

    test "rejects placeholder with spaces" do
      assert {:error, %{message: _}} = Parser.parse_dsl("${email address} exists")
    end
  end
end

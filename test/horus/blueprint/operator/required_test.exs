defmodule Horus.Blueprint.Operator.RequiredTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST.{ComparisonExpression, FieldExpression}
  alias Horus.Blueprint.Operator.Required

  describe "operator metadata" do
    test "has correct operator name" do
      assert Required.operator_name() == :required
    end

    test "has correct expression tag" do
      assert Required.expression_tag() == :required_check
    end

    test "has correct operator aliases" do
      assert Required.operator_aliases() == [
               "must be filled in",
               "must be present"
             ]
    end
  end

  describe "tokens_to_ast/1" do
    test "builds correct AST for simple field" do
      tokens = [{:required_check, [{:placeholder, "email"}, {:operator, :required}]}]

      ast = Required.tokens_to_ast(tokens)

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "builds correct AST for field with underscore" do
      tokens = [{:required_check, [{:placeholder, "first_name"}, {:operator, :required}]}]

      ast = Required.tokens_to_ast(tokens)

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${first_name}", placeholder?: true},
               right: nil
             } = ast
    end

    test "builds correct AST for field with numbers" do
      tokens = [{:required_check, [{:placeholder, "field123"}, {:operator, :required}]}]

      ast = Required.tokens_to_ast(tokens)

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${field123}", placeholder?: true},
               right: nil
             } = ast
    end
  end

  describe "integration with parser" do
    alias Horus.Blueprint.Parser

    test "parses main form 'is required'" do
      {:ok, ast} = Parser.parse_dsl("${email} is required")

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses modal verb form 'must be required'" do
      {:ok, ast} = Parser.parse_dsl("${email} must be required")

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses modal verb form 'should be required'" do
      {:ok, ast} = Parser.parse_dsl("${email} should be required")

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'must be filled in'" do
      {:ok, ast} = Parser.parse_dsl("${email} must be filled in")

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end

    test "parses alias 'must be present'" do
      {:ok, ast} = Parser.parse_dsl("${email} must be present")

      assert %ComparisonExpression{
               operator: :required,
               left: %FieldExpression{path: "${email}", placeholder?: true},
               right: nil
             } = ast
    end
  end
end

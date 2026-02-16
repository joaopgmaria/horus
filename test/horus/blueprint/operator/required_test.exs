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
    # These tests verify that the operator works correctly when integrated
    # with the full parser. They will be added once the operator is registered.

    # test "parses 'is required' correctly" do
    #   alias Horus.Blueprint.Parser
    #   {:ok, ast} = Parser.parse_dsl("${email} is required")
    #   assert %ComparisonExpression{operator: :required} = ast
    # end
  end
end

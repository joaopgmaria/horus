defmodule Horus.Blueprint.AST.Operator.EqualityTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST.Expression.{Comparison, Field, Literal}
  alias Horus.Blueprint.AST.Operator.Equality

  describe "operator metadata" do
    test "has correct operator name" do
      assert Equality.operator_name() == :equality
    end

    test "has correct operator type and precedence" do
      assert Equality.operator_type() == :binary_infix
      assert Equality.precedence() == 50
    end
  end

  describe "tokens_to_ast/1" do
    test "builds correct AST from left and right operands" do
      left = %Field{path: "${left}", placeholder?: true}
      right = %Literal{value: "value", type: :string}
      tokens = [{:equality, [left, right]}]

      assert %Comparison{
               operator: :eq,
               left: ^left,
               right: ^right
             } = Equality.tokens_to_ast(tokens)
    end
  end
end

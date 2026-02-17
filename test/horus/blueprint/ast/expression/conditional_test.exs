defmodule Horus.Blueprint.AST.Expression.ConditionalTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Expression.{Boolean, Comparison, Conditional, Field}

  describe "Conditional" do
    test "creates conditional expression" do
      expr = %Conditional{
        condition: %Comparison{operator: :presence, left: %Field{path: "${a}"}},
        then_expr: %Comparison{operator: :presence, left: %Field{path: "${b}"}}
      }

      assert %Conditional{} = expr
    end

    test "serializes to JSON" do
      expr = %Conditional{
        condition: %Comparison{operator: :presence, left: %Field{path: "${a}"}},
        then_expr: %Comparison{operator: :presence, left: %Field{path: "${b}"}}
      }

      json = Expression.to_json(expr)
      assert json["type"] == "conditional"
      assert json["condition"]["type"] == "comparison"
      assert json["then"]["type"] == "comparison"
    end

    test "extracts parameters from condition and then_expr" do
      expr = %Conditional{
        condition: %Comparison{operator: :presence, left: %Field{path: "${customer}"}},
        then_expr: %Comparison{operator: :presence, left: %Field{path: "${email}"}}
      }

      assert Enum.sort(Expression.extract_parameters(expr)) == ["${customer}", "${email}"]
    end

    test "round-trips (complex) through JSON" do
      original = %Conditional{
        condition: %Boolean{
          operator: :and,
          left: %Comparison{operator: :presence, left: %Field{path: "${a}"}},
          right: %Comparison{operator: :presence, left: %Field{path: "${b}"}}
        },
        then_expr: %Comparison{operator: :presence, left: %Field{path: "${c}"}}
      }

      json = Expression.to_json(original)
      assert AST.from_json(json) == original
    end
  end
end

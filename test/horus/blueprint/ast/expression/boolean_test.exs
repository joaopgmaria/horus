defmodule Horus.Blueprint.AST.Expression.BooleanTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Expression.{Boolean, Comparison, Field}

  describe "Boolean - Logical operators" do
    test "creates logical AND expression" do
      expr = %Boolean{
        operator: :and,
        left: %Field{path: "${a}"},
        right: %Field{path: "${b}"}
      }

      assert expr.operator == :and
      assert expr.left.path == "${a}"
      assert expr.right.path == "${b}"
    end

    test "serializes to JSON" do
      expr = %Boolean{
        operator: :or,
        left: %Field{path: "${a}"},
        right: %Field{path: "${b}"}
      }

      assert Expression.to_json(expr) == %{
               "type" => "boolean",
               "operator" => "or",
               "left" => %{"type" => "field", "path" => "${a}", "placeholder" => true},
               "right" => %{"type" => "field", "path" => "${b}", "placeholder" => true}
             }
    end

    test "extracts parameters from nested operands" do
      expr = %Boolean{
        operator: :and,
        left: %Field{path: "${a}"},
        right: %Comparison{
          operator: :presence,
          left: %Field{path: "${b}"},
          right: nil
        }
      }

      assert Enum.sort(Expression.extract_parameters(expr)) == ["${a}", "${b}"]
    end

    test "deserializes from JSON" do
      json = %{
        "type" => "boolean",
        "operator" => "not",
        "left" => %{"type" => "field", "path" => "${a}", "placeholder" => true},
        "right" => nil
      }

      assert AST.from_json(json) == %Boolean{
               operator: :not,
               left: %Field{path: "${a}"},
               right: nil
             }
    end

    test "round-trips (not) through JSON" do
      original = %Boolean{
        operator: :not,
        left: %Comparison{operator: :presence, left: %Field{path: "${a}"}},
        right: nil
      }

      json = Expression.to_json(original)
      assert AST.from_json(json) == original
    end
  end
end

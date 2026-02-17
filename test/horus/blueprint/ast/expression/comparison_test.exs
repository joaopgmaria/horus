defmodule Horus.Blueprint.AST.Expression.ComparisonTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Expression.{Comparison, Field}

  describe "Comparison - Presence operator" do
    test "creates presence check expression" do
      expr = %Comparison{
        operator: :presence,
        left: %Field{path: "${field}", placeholder?: true},
        right: nil
      }

      assert expr.operator == :presence
      assert expr.left.path == "${field}"
      assert expr.right == nil
    end

    test "serializes presence check to JSON" do
      expr = %Comparison{
        operator: :presence,
        left: %Field{path: "${field}", placeholder?: true},
        right: nil
      }

      assert Expression.to_json(expr) == %{
               "type" => "comparison",
               "operator" => "presence",
               "left" => %{"type" => "field", "path" => "${field}", "placeholder" => true},
               "right" => nil
             }
    end

    test "extracts parameters from presence check" do
      expr = %Comparison{
        operator: :presence,
        left: %Field{path: "${field}", placeholder?: true},
        right: nil
      }

      assert Expression.extract_parameters(expr) == ["${field}"]
    end

    test "deserializes presence check from JSON" do
      json = %{
        "type" => "comparison",
        "operator" => "presence",
        "left" => %{"type" => "field", "path" => "${field}", "placeholder" => true},
        "right" => nil
      }

      assert AST.from_json(json) == %Comparison{
               operator: :presence,
               left: %Field{path: "${field}", placeholder?: true},
               right: nil
             }
    end

    test "extracts multiple occurrences of same parameter" do
      expr = %Comparison{
        operator: :presence,
        left: %Field{path: "${field}", placeholder?: true},
        right: nil
      }

      params = Expression.extract_parameters(expr)
      assert params == ["${field}"]
    end

    test "round-trips (presence) through JSON" do
      original = %Comparison{
        operator: :presence,
        left: %Field{path: "${email}", placeholder?: true},
        right: nil
      }

      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end
  end
end

defmodule Horus.Blueprint.ASTTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression

  alias Horus.Blueprint.AST.Expression.{
    Comparison,
    Field
  }

  describe "Field" do
    test "creates with path and placeholder flag" do
      expr = %Field{path: "${field}", placeholder?: true}
      assert expr.path == "${field}"
      assert expr.placeholder? == true
    end

    test "defaults placeholder? to true" do
      expr = %Field{path: "${field}"}
      assert expr.placeholder? == true
    end

    test "serializes to JSON" do
      expr = %Field{path: "${field}", placeholder?: true}

      assert Expression.to_json(expr) == %{
               "type" => "field",
               "path" => "${field}",
               "placeholder" => true
             }
    end

    test "serializes literal path to JSON" do
      expr = %Field{path: "/customer/email", placeholder?: false}

      assert Expression.to_json(expr) == %{
               "type" => "field",
               "path" => "/customer/email",
               "placeholder" => false
             }
    end

    test "extracts parameters from placeholder" do
      expr = %Field{path: "${field}", placeholder?: true}
      assert Expression.extract_parameters(expr) == ["${field}"]
    end

    test "does not extract parameters from literal path" do
      expr = %Field{path: "/customer/email", placeholder?: false}
      assert Expression.extract_parameters(expr) == []
    end

    test "deserializes from JSON" do
      json = %{"type" => "field", "path" => "${field}", "placeholder" => true}
      assert AST.from_json(json) == %Field{path: "${field}", placeholder?: true}
    end
  end

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
      # Note: Presence operator only has one field, but this tests parameter extraction behavior
      expr = %Comparison{
        operator: :presence,
        left: %Field{path: "${field}", placeholder?: true},
        right: nil
      }

      params = Expression.extract_parameters(expr)
      assert params == ["${field}"]
    end
  end

  describe "round-trip serialization - Presence operator" do
    test "Field round-trips through JSON" do
      original = %Field{path: "${customer_email}", placeholder?: true}
      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end

    test "Comparison (presence) round-trips through JSON" do
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

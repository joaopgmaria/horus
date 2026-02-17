defmodule Horus.Blueprint.AST.Expression.FieldTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Expression.Field

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

    test "round-trips through JSON" do
      original = %Field{path: "${customer_email}", placeholder?: true}
      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end
  end
end

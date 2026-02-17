defmodule Horus.Blueprint.AST.Expression.LiteralTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Expression.Literal

  describe "Literal" do
    test "creates literal with value and type" do
      expr = %Literal{value: "Horus", type: :string}
      assert expr.value == "Horus"
      assert expr.type == :string
    end

    test "serializes to JSON" do
      expr = %Literal{value: 42, type: :integer}

      assert Expression.to_json(expr) == %{
               "type" => "literal",
               "value" => 42,
               "value_type" => "integer"
             }
    end

    test "extracts no parameters" do
      expr = %Literal{value: "Horus", type: :string}
      assert Expression.extract_parameters(expr) == []
    end

    test "deserializes from JSON" do
      json = %{"type" => "literal", "value" => true, "value_type" => "boolean"}
      assert AST.from_json(json) == %Literal{value: true, type: :boolean}
    end

    test "round-trips through JSON" do
      original = %Literal{value: 123.45, type: :number}
      json = Expression.to_json(original)
      assert AST.from_json(json) == original
    end
  end
end

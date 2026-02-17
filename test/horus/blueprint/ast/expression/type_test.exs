defmodule Horus.Blueprint.AST.Expression.TypeTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression
  alias Horus.Blueprint.AST.Expression.Type

  describe "Type" do
    test "creates type expression" do
      expr = %Type{type: :string}
      assert expr.type == :string
    end

    test "serializes to JSON" do
      expr = %Type{type: :integer}

      assert Expression.to_json(expr) == %{
               "type" => "type",
               "value" => "integer"
             }
    end

    test "extracts no parameters" do
      expr = %Type{type: :string}
      assert Expression.extract_parameters(expr) == []
    end

    test "deserializes from JSON" do
      json = %{"type" => "type", "value" => "boolean"}
      assert AST.from_json(json) == %Type{type: :boolean}
    end

    test "round-trips through JSON" do
      original = %Type{type: :number}
      json = Expression.to_json(original)
      assert AST.from_json(json) == original
    end
  end
end

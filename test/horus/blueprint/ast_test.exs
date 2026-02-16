defmodule Horus.Blueprint.ASTTest do
  use ExUnit.Case, async: true

  alias Horus.Blueprint.AST
  alias Horus.Blueprint.AST.Expression

  alias Horus.Blueprint.AST.{
    ComparisonExpression,
    ConditionalExpression,
    FieldExpression,
    TypeExpression
  }

  describe "FieldExpression" do
    test "creates with path and placeholder flag" do
      expr = %FieldExpression{path: "${field}", placeholder?: true}
      assert expr.path == "${field}"
      assert expr.placeholder? == true
    end

    test "defaults placeholder? to true" do
      expr = %FieldExpression{path: "${field}"}
      assert expr.placeholder? == true
    end

    test "serializes to JSON" do
      expr = %FieldExpression{path: "${field}", placeholder?: true}

      assert Expression.to_json(expr) == %{
               "type" => "field",
               "path" => "${field}",
               "placeholder" => true
             }
    end

    test "serializes literal path to JSON" do
      expr = %FieldExpression{path: "/customer/email", placeholder?: false}

      assert Expression.to_json(expr) == %{
               "type" => "field",
               "path" => "/customer/email",
               "placeholder" => false
             }
    end

    test "extracts parameters from placeholder" do
      expr = %FieldExpression{path: "${field}", placeholder?: true}
      assert Expression.extract_parameters(expr) == ["${field}"]
    end

    test "does not extract parameters from literal path" do
      expr = %FieldExpression{path: "/customer/email", placeholder?: false}
      assert Expression.extract_parameters(expr) == []
    end

    test "deserializes from JSON" do
      json = %{"type" => "field", "path" => "${field}", "placeholder" => true}
      assert AST.from_json(json) == %FieldExpression{path: "${field}", placeholder?: true}
    end
  end

  describe "TypeExpression" do
    test "creates with type atom" do
      expr = %TypeExpression{type: :string}
      assert expr.type == :string
    end

    test "supports all type atoms" do
      types = [:string, :integer, :number, :boolean, :array, :object]

      for type <- types do
        expr = %TypeExpression{type: type}
        assert expr.type == type
      end
    end

    test "serializes to JSON" do
      expr = %TypeExpression{type: :string}

      assert Expression.to_json(expr) == %{
               "type" => "type",
               "value" => "string"
             }
    end

    test "does not extract parameters" do
      expr = %TypeExpression{type: :string}
      assert Expression.extract_parameters(expr) == []
    end

    test "deserializes from JSON" do
      json = %{"type" => "type", "value" => "integer"}
      assert AST.from_json(json) == %TypeExpression{type: :integer}
    end
  end

  describe "ComparisonExpression" do
    test "creates with operator and left/right expressions" do
      expr = %ComparisonExpression{
        operator: :is_a,
        left: %FieldExpression{path: "${field}"},
        right: %TypeExpression{type: :string}
      }

      assert expr.operator == :is_a
      assert expr.left == %FieldExpression{path: "${field}"}
      assert expr.right == %TypeExpression{type: :string}
    end

    test "supports nil right for required operator" do
      expr = %ComparisonExpression{
        operator: :presence,
        left: %FieldExpression{path: "${field}"},
        right: nil
      }

      assert expr.right == nil
    end

    test "serializes type check to JSON" do
      expr = %ComparisonExpression{
        operator: :is_a,
        left: %FieldExpression{path: "${field}"},
        right: %TypeExpression{type: :string}
      }

      assert Expression.to_json(expr) == %{
               "type" => "comparison",
               "operator" => "is_a",
               "left" => %{
                 "type" => "field",
                 "path" => "${field}",
                 "placeholder" => true
               },
               "right" => %{
                 "type" => "type",
                 "value" => "string"
               }
             }
    end

    test "serializes required check with nil right" do
      expr = %ComparisonExpression{
        operator: :presence,
        left: %FieldExpression{path: "${field}"},
        right: nil
      }

      json = Expression.to_json(expr)
      assert json["operator"] == "presence"
      assert json["right"] == nil
    end

    test "extracts parameters from left only" do
      expr = %ComparisonExpression{
        operator: :is_a,
        left: %FieldExpression{path: "${field}"},
        right: %TypeExpression{type: :string}
      }

      assert Expression.extract_parameters(expr) == ["${field}"]
    end

    test "extracts parameters from both left and right" do
      expr = %ComparisonExpression{
        operator: :equals,
        left: %FieldExpression{path: "${field}"},
        right: %FieldExpression{path: "${expected}"}
      }

      params = Expression.extract_parameters(expr)
      assert Enum.sort(params) == ["${expected}", "${field}"]
    end

    test "preserves duplicate parameters for counting" do
      expr = %ComparisonExpression{
        operator: :equals,
        left: %FieldExpression{path: "${field}"},
        right: %FieldExpression{path: "${field}"}
      }

      # Should include duplicates so Compiler can count occurrences
      assert Expression.extract_parameters(expr) == ["${field}", "${field}"]
    end

    test "deserializes from JSON" do
      json = %{
        "type" => "comparison",
        "operator" => "is_a",
        "left" => %{"type" => "field", "path" => "${field}", "placeholder" => true},
        "right" => %{"type" => "type", "value" => "string"}
      }

      result = AST.from_json(json)

      assert %ComparisonExpression{
               operator: :is_a,
               left: %FieldExpression{path: "${field}"},
               right: %TypeExpression{type: :string}
             } = result
    end
  end

  describe "ConditionalExpression" do
    test "creates with condition and then_expr" do
      expr = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${country}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${postal_code}"},
          right: nil
        }
      }

      assert %ComparisonExpression{operator: :is_a} = expr.condition
      assert %ComparisonExpression{operator: :presence} = expr.then_expr
    end

    test "serializes to JSON" do
      expr = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${country}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${postal_code}"},
          right: nil
        }
      }

      json = Expression.to_json(expr)

      assert json["type"] == "conditional"
      assert json["condition"]["operator"] == "is_a"
      assert json["condition"]["left"]["path"] == "${country}"
      assert json["then"]["operator"] == "presence"
      assert json["then"]["left"]["path"] == "${postal_code}"
    end

    test "extracts parameters from both condition and then_expr" do
      expr = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${country}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${postal_code}"},
          right: nil
        }
      }

      params = Expression.extract_parameters(expr)
      assert Enum.sort(params) == ["${country}", "${postal_code}"]
    end

    test "preserves duplicate parameters across branches for counting" do
      expr = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${field}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${field}"},
          right: nil
        }
      }

      # Should include duplicates so Compiler can count occurrences
      assert Expression.extract_parameters(expr) == ["${field}", "${field}"]
    end

    test "deserializes from JSON" do
      json = %{
        "type" => "conditional",
        "condition" => %{
          "type" => "comparison",
          "operator" => "is_a",
          "left" => %{"type" => "field", "path" => "${country}", "placeholder" => true},
          "right" => %{"type" => "type", "value" => "string"}
        },
        "then" => %{
          "type" => "comparison",
          "operator" => "presence",
          "left" => %{"type" => "field", "path" => "${postal_code}", "placeholder" => true},
          "right" => nil
        }
      }

      result = AST.from_json(json)

      assert %ConditionalExpression{
               condition: %ComparisonExpression{operator: :is_a},
               then_expr: %ComparisonExpression{operator: :presence}
             } = result
    end
  end

  describe "round-trip serialization" do
    test "FieldExpression survives round-trip" do
      original = %FieldExpression{path: "${field}", placeholder?: true}
      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end

    test "TypeExpression survives round-trip" do
      original = %TypeExpression{type: :integer}
      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end

    test "ComparisonExpression survives round-trip" do
      original = %ComparisonExpression{
        operator: :equals,
        left: %FieldExpression{path: "${field}"},
        right: %FieldExpression{path: "${value}"}
      }

      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end

    test "ConditionalExpression survives round-trip" do
      original = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :is_a,
          left: %FieldExpression{path: "${country}"},
          right: %TypeExpression{type: :string}
        },
        then_expr: %ComparisonExpression{
          operator: :presence,
          left: %FieldExpression{path: "${postal_code}"},
          right: nil
        }
      }

      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end

    test "nested ConditionalExpression survives round-trip" do
      original = %ConditionalExpression{
        condition: %ComparisonExpression{
          operator: :equals,
          left: %FieldExpression{path: "${status}"},
          right: %FieldExpression{path: "${expected_status}"}
        },
        then_expr: %ConditionalExpression{
          condition: %ComparisonExpression{
            operator: :is_a,
            left: %FieldExpression{path: "${amount}"},
            right: %TypeExpression{type: :number}
          },
          then_expr: %ComparisonExpression{
            operator: :presence,
            left: %FieldExpression{path: "${currency}"},
            right: nil
          }
        }
      }

      json = Expression.to_json(original)
      deserialized = AST.from_json(json)

      assert deserialized == original
    end
  end
end

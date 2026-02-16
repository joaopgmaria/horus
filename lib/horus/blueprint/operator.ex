defmodule Horus.Blueprint.Operator do
  @moduledoc """
  Behaviour for Blueprint DSL operators.

  Each operator defines how to parse its syntax and build AST nodes.
  All operators are expressions that can be evaluated.

  ## Implementing an Operator

  To create a new operator, implement all four callbacks:

      defmodule MyOperator do
        @behaviour Horus.Blueprint.Operator

        @impl true
        def operator_name, do: :my_operator

        @impl true
        def expression_tag, do: :my_operator_check

        @impl true
        def parser_combinator(ctx) do
          # Build NimbleParsec combinator using ctx primitives
        end

        @impl true
        def tokens_to_ast(tokens) do
          # Convert parsed tokens to AST expression
        end
      end

  ## Operator Registry

  Once implemented, register the operator in `Horus.Blueprint.Operator.Registry`
  by adding it to the `@operators` module attribute. The registry will automatically
  compose all operators into the parser.
  """

  @doc """
  Returns the operator's unique identifier.

  This name is used for internal identification and logging.

  ## Examples

      iex> MyOperator.operator_name()
      :my_operator
  """
  @callback operator_name() :: atom()

  @doc """
  Returns the token tag used to identify this operator's parsed output.

  Tags must be unique across all operators. The registry uses these tags
  to dispatch tokens to the correct operator for AST construction.

  ## Examples

      iex> MyOperator.expression_tag()
      :my_operator_check
  """
  @callback expression_tag() :: atom()

  @doc """
  Returns a NimbleParsec combinator that parses this operator's syntax.

  The combinator receives a context map containing shared parsing primitives:
  - `placeholder` - Parses `${identifier}` placeholders
  - `whitespace` - Required whitespace (1+ spaces/tabs)
  - `optional_whitespace` - Optional whitespace
  - `type_name` - Parses type names (string, integer, etc.)

  The combinator must tag its output with the operator's expression tag.

  ## Examples

      def parser_combinator(ctx) do
        ctx.placeholder
        |> ignore(ctx.whitespace)
        |> string("my_operator")
        |> tag(:my_operator_check)
      end
  """
  @callback parser_combinator(context :: map()) :: NimbleParsec.t()

  @doc """
  Converts parsed tokens into an AST expression.

  Receives tokens tagged with this operator's expression tag and constructs
  the corresponding AST node (typically a ComparisonExpression or ConditionalExpression).

  ## Examples

      def tokens_to_ast([{:my_operator_check, tokens}]) do
        %ComparisonExpression{
          operator: :my_operator,
          # ... build AST from tokens
        }
      end
  """
  @callback tokens_to_ast(tokens :: list()) :: Horus.Blueprint.AST.Expression.t()
end

defmodule Horus.Blueprint.AST.Operator do
  @moduledoc """
  Behaviour for Blueprint DSL operators.

  Each operator defines how to parse its syntax and build AST nodes.
  All operators are expressions that can be evaluated.

  ## Implementing an Operator

  To create a new operator, use this module and implement the required callbacks.
  The `parser_combinator/1` is provided automatically by default:

      defmodule MyOperator do
        use Horus.Blueprint.AST.Operator

        @impl true
        def operator_name, do: :my_operator

        @impl true
        def operator_forms do
          [
            "exists",
            "is present",
            "must be present"
          ]
        end

        @impl true
        def tokens_to_ast(tokens) do
          # Convert parsed tokens to AST expression
        end
      end

  The default `parser_combinator/1` implementation works for most operators.
  Override it only if you need custom parsing logic.

  ## Operator Registry

  Once implemented, register the operator in `Horus.Blueprint.AST.Operator.Registry`
  by adding it to the `@operators` module attribute. The registry will automatically
  compose all operators into the parser.
  """

  import NimbleParsec

  @doc """
  Use this module to implement an operator with default implementations.

  Provides a default implementation for `parser_combinator/1` that works
  for most operators. Override it if you need custom parsing logic.

  ## Example

      defmodule MyOperator do
        use Horus.Blueprint.AST.Operator

        @impl true
        def operator_name, do: :my_operator

        @impl true
        def operator_forms, do: ["my form", "alternative form"]

        @impl true
        def tokens_to_ast(tokens) do
          # Convert tokens to AST
        end
      end
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Horus.Blueprint.AST.Operator
      import NimbleParsec

      @doc """
      Default parser combinator implementation.

      Builds a combinator by iterating over all operator forms and wrapping
      them in a choice combinator. This works for most operators that follow
      the standard pattern of `${field} <operator_form>`.

      Override this function if your operator needs custom parsing logic.
      """
      @impl true
      def parser_combinator(ctx) do
        Horus.Blueprint.AST.Operator.build_parser_combinator(
          ctx,
          operator_forms(),
          operator_type(),
          operator_name()
        )
      end

      @impl true
      def operator_type, do: :atomic

      @impl true
      def precedence, do: 100

      @impl true
      def atomic?, do: operator_type() == :atomic

      defoverridable parser_combinator: 1, atomic?: 0, operator_type: 0, precedence: 0
    end
  end

  @doc """
  Returns the operator's unique identifier.

  This name is used for internal identification and logging.

  ## Examples

      iex> MyOperator.operator_name()
      :my_operator
  """
  @callback operator_name() :: atom()

  @doc """
  Returns the type of the operator.

  Supported types:
  - `:atomic` - Applies to a single field, e.g. `${field} exists`
  - `:unary_prefix` - A unary operator with prefix syntax, e.g. `not <expr>`
  - `:binary_infix` - A binary operator with infix syntax, e.g. `<expr> and <expr>`
  - `:primary` - A primary expression (literals, constants), e.g. `true`, `"string"`
  """
  @callback operator_type() :: :atomic | :unary_prefix | :binary_infix | :primary

  @doc """
  Returns the precedence of the operator.
  Higher numbers represent higher precedence (evaluated first).

  Standard precedences:
  - 100: Atomic / Primary expressions
  - 30: Unary NOT
  - 20: Binary AND
  - 10: Binary OR
  """
  @callback precedence() :: integer()

  @doc """
  Returns whether this operator is "atomic" (applies to a single field).
  Derived from `operator_type() == :atomic` by default.
  """
  @callback atomic?() :: boolean()

  @doc """
  ## Examples

      # Presence operator with multiple forms
      def operator_forms do
        [
          "exists",              # Main form
          "is required",         # Alias 1
          "is present",          # Alias 2
          "must be present",     # Alias 3
          "must be filled in"    # Alias 4
        ]
      end

      # Operator with single form
      def operator_forms, do: ["my_operator"]

  @doc \"""
  Returns all supported forms for this operator.

  This includes the main form and all alternative phrasings (aliases).
  All forms are semantically equivalent and compile to the same AST.

  Returns a list of complete operator phrases.
  """
  @callback operator_forms() :: [String.t()]

  @doc """
  Returns a NimbleParsec combinator that parses this operator's syntax.

  **Default Implementation**: When you `use Horus.Blueprint.AST.Operator`, a default
  implementation is provided that works for most operators. It iterates over
  `operator_forms/0` and builds combinators for each form.

  **Override** this callback only if your operator needs custom parsing logic
  that doesn't follow the standard `${field} <operator_form>` pattern.

  The combinator receives a context map containing shared parsing primitives:
  - `placeholder` - Parses `${identifier}` placeholders
  - `whitespace` - Required whitespace (1+ spaces/tabs)
  - `optional_whitespace` - Optional whitespace
  - `type_name` - Parses type names (string, integer, etc.)

  The combinator must tag its output with the operator name.

  ## Default Implementation (provided automatically)

      def parser_combinator(ctx) do
        operator_forms()
        |> Enum.map(&Horus.Blueprint.AST.Operator.build_form_combinator(ctx, &1, operator_name()))
        |> choice()
      end

  ## Custom Implementation Example

      # Only needed if you need special parsing logic
      def parser_combinator(ctx) do
        # Custom combinator logic here
      end
  """
  @callback parser_combinator(context :: map()) :: NimbleParsec.t()

  @doc """
  Converts parsed tokens into an AST expression.

  Receives tokens tagged with this operator's expression tag and constructs
  the corresponding AST node (typically a Comparison or Conditional).

  ## Examples

      def tokens_to_ast([{:my_operator_check, tokens}]) do
        %Comparison{
          operator: :my_operator,
          # ... build AST from tokens
        }
      end
  """
  @callback tokens_to_ast(tokens :: list()) :: Horus.Blueprint.AST.Expression.t()

  @doc """
  Builds a parser combinator for the given forms and operator type.
  Used by the default implementation of `parser_combinator/1`.
  """
  @spec build_parser_combinator(map(), [String.t()], atom(), atom()) :: NimbleParsec.t()
  def build_parser_combinator(ctx, forms, type, name) do
    case forms do
      [] ->
        empty()

      [single_form] ->
        build_form_or_symbol_combinator(ctx, single_form, type, name)

      forms ->
        forms
        |> Enum.sort_by(&String.length/1, :desc)
        |> Enum.map(&build_form_or_symbol_combinator(ctx, &1, type, name))
        |> choice()
    end
  end

  defp build_form_or_symbol_combinator(ctx, form, :atomic, name) do
    build_form_combinator(ctx, form, name)
  end

  defp build_form_or_symbol_combinator(ctx, form, _type, name) do
    build_symbol_combinator(ctx, form, name)
  end

  @doc """
  Builds a NimbleParsec combinator for a single operator form.

  This helper function constructs a combinator that:
  1. Parses the placeholder (${field})
  2. Parses whitespace
  3. Parses each word in the form phrase with whitespace between them
  4. Tags the result with the operator symbol and expression tag

  ## Parameters

  - `ctx` - Parser context map with shared combinators
  - `form` - Complete operator phrase (e.g., "must be present")
  - `operator_atom` - Operator symbol (e.g., :presence)

  ## Examples

      build_form_combinator(ctx, "exists", :presence)
      # Produces combinator that parses: ${field} exists

      build_form_combinator(ctx, "must be present", :presence)
      # Produces combinator that parses: ${field} must be present
  """
  @spec build_form_combinator(map(), String.t(), atom()) :: NimbleParsec.t()
  def build_form_combinator(ctx, form_phrase, operator_atom) do
    # For atomic operators: placeholder <ws> word1 <ws> word2 ...
    # Placeholder
    ctx.placeholder
    # build_symbol_combinator will add whitespace before the first word
    # since acc (placeholder) is not empty()
    |> build_symbol_combinator(ctx, form_phrase, operator_atom)
    # Tag it for atomic dispatch
    |> tag(operator_atom)
  end

  @doc """
  Builds a NimbleParsec combinator for an operator symbol/phrase.
  Does NOT include the placeholder or trailing tag. Used for infix and unary operators.
  """
  @spec build_symbol_combinator(map(), String.t(), atom()) :: NimbleParsec.t()
  def build_symbol_combinator(ctx, form_phrase, operator_atom) do
    # For infix/unary, Registry handles leading space, so leading_ws? is false.
    build_symbol_combinator_logic(empty(), ctx, form_phrase, operator_atom, false)
  end

  @doc """
  Builds a NimbleParsec combinator for an operator symbol/phrase, starting from an accumulator.
  Used by atomic operators to build on top of the placeholder and whitespace.
  """
  @spec build_symbol_combinator(NimbleParsec.t(), map(), String.t(), atom()) :: NimbleParsec.t()
  def build_symbol_combinator(acc, ctx, form_phrase, operator_atom) do
    # For atomic: we ALREADY matching placeholder, now we need WS then first word.
    build_symbol_combinator_logic(acc, ctx, form_phrase, operator_atom, true)
  end

  defp build_symbol_combinator_logic(acc, ctx, form_phrase, operator_atom, leading_ws?) do
    combinator =
      if leading_ws? do
        acc |> ignore(ctx.whitespace) |> ignore(string(form_phrase))
      else
        acc |> ignore(string(form_phrase))
      end

    # Add the operator identity token
    op_token = empty() |> replace(operator_atom) |> unwrap_and_tag(:operator)

    combinator
    |> concat(op_token)
  end
end

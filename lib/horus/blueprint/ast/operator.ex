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
        # Build combinators for all forms dynamically
        operator_forms()
        |> Enum.map(
          &Horus.Blueprint.AST.Operator.build_form_combinator(
            ctx,
            &1,
            operator_name()
          )
        )
        |> choice()
      end

      defoverridable parser_combinator: 1
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
  Returns all supported forms for this operator.

  This includes the main form and all alternative phrasings (aliases).
  All forms are semantically equivalent and compile to the same AST.

  Returns a list of complete operator phrases.

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

  ## Notes

  - First form is conventionally the "main" form
  - All forms should be complete operator phrases
  - Forms are tried in order - more specific forms should come first
  - All forms compile to the same operator AST
  - Global modal substitutions ("is" → "must be"/"should be") are NOT needed here
  """
  @callback operator_forms() :: [String.t(), ...]

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
    # Split form phrase into words
    words = String.split(form_phrase, " ")

    # Build combinator that matches all words in sequence with whitespace between them
    combinator =
      Enum.reduce(words, ctx.placeholder, fn word, acc ->
        acc
        |> ignore(ctx.whitespace)
        |> ignore(string(word))
      end)

    # Add the operator token and tag with operator name
    combinator
    |> concat(empty() |> replace(operator_atom) |> unwrap_and_tag(:operator))
    |> tag(operator_atom)
  end
end

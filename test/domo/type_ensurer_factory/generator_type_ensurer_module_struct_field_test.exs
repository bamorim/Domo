defmodule Domo.TypeEnsurerFactory.GeneratorTypeEnsurerModuleStructFieldTest do
  use Domo.FileCase, async: false

  alias Domo.TypeEnsurerFactory.Generator

  setup do
    on_exit(fn ->
      :code.purge(TypeEnsurer)
      :code.delete(TypeEnsurer)
    end)

    :ok
  end

  def type_ensurer_quoted(field_spec) do
    Generator.do_type_ensurer_module(Elixir, field_spec)
  end

  def load_type_ensurer_module(field_spec) do
    field_spec
    |> type_ensurer_quoted()
    |> Code.eval_quoted()
  end

  def call_ensure_type({_field, _value} = subject) do
    apply(TypeEnsurer, :ensure_type!, [subject])
  end

  describe "TypeEnsurer module for field of struct type that does not use Domo" do
    test "ensures field's value" do
      load_type_ensurer_module(%{
        first: [quote(do: %CustomStruct{})]
      })

      assert :ok == call_ensure_type({:first, %CustomStruct{title: :one}})
      assert :ok == call_ensure_type({:first, %CustomStruct{title: nil}})
      assert :ok == call_ensure_type({:first, %CustomStruct{title: "one"}})
      assert {:error, _} = call_ensure_type({:first, %{}})
      assert {:error, _} = call_ensure_type({:first, :not_a_struct})
    end

    test "ensures field's value accounting given struct's keys and value types" do
      load_type_ensurer_module(%{
        first: [quote(do: %CustomStruct{title: <<_::_*8>>}), quote(do: %CustomStruct{title: nil})]
      })

      assert :ok == call_ensure_type({:first, %CustomStruct{title: "one"}})
      assert :ok == call_ensure_type({:first, %CustomStruct{title: nil}})
      assert {:error, _} = call_ensure_type({:first, %CustomStruct{title: :one}})
      assert {:error, _} = call_ensure_type({:first, %{}})
      assert {:error, _} = call_ensure_type({:first, :not_a_struct})
    end
  end

  describe "TypeEnsurer module for field of struct that use Domo" do
    test "ensures field's value by delegating to the struct's TypeEnsurer" do
      load_type_ensurer_module(%{
        first: [
          quote(do: %CustomStructUsingDomo{}),
          quote(do: %CustomStructUsingDomo{title: nil})
        ]
      })

      assert_raise RuntimeError, ~r/CustomStructUsingDomo.TypeEnsurer/, fn ->
        call_ensure_type({:first, %CustomStructUsingDomo{title: :one}})
      end
    end

    test "should have only universal match_spec function for the struct" do
      ensurer_quoted =
        type_ensurer_quoted(%{
          first: [
            quote(do: %CustomStructUsingDomo{title: <<_::_*8>>}),
            quote(do: %CustomStructUsingDomo{title: nil}),
            quote(do: nil)
          ]
        })

      ensurer_string = Macro.to_string(ensurer_quoted)

      match_specs = Regex.scan(~r(%CustomStructUsingDomo{), ensurer_string)

      assert length(match_specs) == 4
    end

    test "should have only universal match_spec function for the struct in nested container" do
      ensurer_quoted =
        type_ensurer_quoted(%{
          first: [
            quote(do: [{%CustomStructUsingDomo{title: <<_::_*8>>}}]),
            quote(do: [{%CustomStructUsingDomo{title: nil}}]),
            quote(do: nil)
          ]
        })

      ensurer_string = Macro.to_string(ensurer_quoted)

      match_specs = Regex.scan(~r(%CustomStructUsingDomo{), ensurer_string)

      assert length(match_specs) == 14
    end
  end
end
defmodule ListOfUnions do
  use Domo

  defstruct values: []

  @type my_string() :: String.t()
  precond(my_string: &check_my_string/1)

  defp check_my_string(string) do
    String.length(string) > 0
  end

  @type t() :: %__MODULE__{
          values: list(integer() | String.t())
        }
end

defmodule Identification do
  @doc """
  Is given binary data an instance of behaviour's implementor?
  """
  @callback is?(binary) :: boolean
  @doc """
  What extension should be applied to such a file on disk
  """
  @callback extension() :: String.t()

  @doc """
  Loop through all implementations of behavior to try to identify a given file
  Input will be treated as binary data if no file can be found with the name input.
  """
  @spec identify(binary) :: {:ok, atom} | {:error, String.t()}
  def identify(input) do
    binary_data = 
      if File.exists?(input) and not File.dir?(input) do
        File.stream!(input, [], 1) |> Enum.to_list |> :erlang.list_to_binary
      else
        input
      end
    match =
      :code.all_loaded()
      |> Enum.filter(fn {module, _} ->
        module.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()
        |> Enum.member?(Identification)
      end)
      |> Enum.find(&elem(&1, 0).is?(binary_data))

      if match == nil do
        {:error, "Could not match file type"}
      else
        {:ok, elem(match, 0)}
      end
  end
end

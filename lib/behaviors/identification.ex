defmodule Identification do
  @doc """
  Is given file an instance of module filetype or not?
  """
  @callback is?(String.t()) :: boolean
  @doc """
  What extension should be applied to such a file on disk
  """
  @callback extension() :: String.t()

  @doc """
  Loop through all implementations of behavior to try to identify a given file
  """
  @spec identify(String.t()) :: {:ok, atom} | {:error, String.t()}
  def identify(file_name) do
    if File.exists?(file_name) and not File.dir?(file_name) do
      match =
        :code.all_loaded()
        |> Enum.filter(fn {module, _} ->
          module.module_info(:attributes)
          |> Keyword.get_values(:behaviour)
          |> List.flatten()
          |> Enum.member?(Identification)
        end)
        |> Enum.find(&elem(&1, 0).is?(file_name))

      if match == nil do
        {:error, "Could not match file type"}
      else
        {:ok, elem(match, 0)}
      end
    end
  end
end

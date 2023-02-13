defmodule Extractor do
  @doc """
  Extracts files from a given archive
  """
  @callback extract(String.t) :: {:ok, [String.t]} | {:error, String.t}
end

defmodule Archiver do
  @doc """
  Insertsd files into an archive
  """
  @callback archive(String.t, [String.t]) :: {:ok, binary} | {:error, String.t}
end

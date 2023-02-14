defmodule Extractor do
  @doc """
  Extracts files from a given archive
  """
  @callback extract(binary) :: {:ok, binary} | {:ok, [key: binary]} | {:error, String.t}
end

defmodule Archiver do
  @doc """
  Inserts files into an archive
  """
  @callback archive([String.t] | binary) :: {:ok, binary} | {:error, String.t}
end

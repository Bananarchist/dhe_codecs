defmodule PngProducer do
  @doc """
  Produces a PNG file from input
  """
  @callback to_png(any) :: {:ok, binary} | {:error, String.t}
end

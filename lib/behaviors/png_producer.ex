defmodule PngProducer do
  @doc """
  Produces a PNG file from input
  """
  @callback to_png(String.t) :: {:ok, binary} | {:error, String.t}
end

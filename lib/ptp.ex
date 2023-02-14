defmodule Ptp do
  @behaviour Identification
  
  @magic_number << 0x50, 0x54, 0x50, 0x00 >>

  @impl Identification
  def is?(input) do
    << 
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input
    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "ptp"


  def parse_ptp(stream) do
    <<
      magic_number::bitstring-size(32),
    >> = stream
      |> Stream.take(0x04)
      |> Enum.to_list()
      |> :erlang.list_to_binary()
  end
end

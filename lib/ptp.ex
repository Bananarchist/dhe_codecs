defmodule Ptp do
  @behaviour Identification
  
  @magic_number << 0x50, 0x54, 0x50, 0x00 >>

  @impl Identification
  def is?(file_name) do
    << 
      magic_number::bitstring-size(32)
    >> = File.stream!(file_name, [], 1)
      |> Stream.take(0x04)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

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

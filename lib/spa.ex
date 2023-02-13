defmodule Spa do
  @behaviour Identification
  
  @magic_number << 0x53, 0x50, 0x41, 0x00 >>

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
end


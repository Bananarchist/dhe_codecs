defmodule Cns do
  @behaviour Identification
  
  @magic_number << 0x40, 0x43, 0x4E, 0x53 >>

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
  def extension(), do: "cns"

end

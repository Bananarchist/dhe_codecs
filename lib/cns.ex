defmodule Cns do
  @behaviour Identification
  
  @magic_number << 0x40, 0x43, 0x4E, 0x53 >>

  @impl Identification
  def is?(input) do
    << 
      magic_number::bitstring-size(32),
      _rest
    >> = input
    magic_number == @magic_number
  end
  
  @impl Identification
  def extension(), do: "cns"

end

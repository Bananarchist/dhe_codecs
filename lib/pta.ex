defmodule Pta do
  @behaviour Identification
  
  @magic_number << 0x50, 0x54, 0x41, 0x00 >>

  @impl Identification
  def is?(input) do
    << 
      magic_number::bitstring-size(32),
      _rest
    >> = input
    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "pta"

end


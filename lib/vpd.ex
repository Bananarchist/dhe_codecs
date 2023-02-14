defmodule Vpd do
  @behaviour Identification
  
  @magic_number << 0x56, 0x50, 0x44, 0x00 >>

  @impl Identification
  def is?(input) do
    << 
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input
    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "vpd"
end

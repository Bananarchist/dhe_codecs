defmodule Spa do
  @behaviour Identification
  
  @magic_number << 0x53, 0x50, 0x41, 0x00 >>

  @impl Identification
  def is?(input) do
    << 
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input
    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "spa"


  def parse_spa(stream) do
    if not is?(Stream.take(stream, 0x04) |> Enum.to_list |> :erlang.list_to_binary) do
      {:error, "Magic number does not match SPA file"}
    else
      <<
        unknown1::little-integer-size(32),
        data_length::little-integer-size(32),
        unknown2::little-integer-size(32),
        unknown3::little-integer-size(32),
        unknown4::little-integer-size(32),
        unknown5::little-integer-size(32),
        data_offset::little-integer-size(32)
      >> = stream
        |> Stream.drop(0x04)
        |> Stream.take(0x1C)
        |> Enum.to_list()
        |> :erlang.list_to_binary()

      %{
        data_length: data_length,
        data_offset: data_offset,
        unknowns: %{
          at0x04: unknown1,
          at0x0C: unknown2,
          at0x10: unknown3,
          at0x14: unknown4,
          at0x18: unknown5
        }
      }
    end
  end
end


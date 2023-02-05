defmodule Ptg do

  @magic_number << 0x50, 0x54, 0x47, 0x40 >>

  def parse_ptg(stream) do
    <<
      magic_number::bitstring-size(32),
      assembly_offset::little-integer-size(32),
      ptx1_offset::little-integer-size(32),
      ptx2_offset::little-integer-size(32),
      unknown1::little-integer-size(16),
      unknown2::little-integer-size(16),
      unknown3::little-integer-size(32),
      zeroes::bitstring-size(64)
    >> = stream
        |> Stream.take(0x20)
        |> Enum.to_list()
        |> :erlang.list_to_binary()

    if magic_number != @magic_number do
      {:error, "Does not appear to be a PTG file - magic number did not match"}
    else
      assembly_data 
        = stream
        |> Stream.drop(assembly_offset)
        |> Stream.take(ptx1_offset - assembly_offset)
        |> Stream.chunk_every(0x14, 0x14, :discard)
        |> Enum.map(&parse_assembly_data/1)
      %{ 
        ptx1: ptx1_offset, 
        ptx2: ptx2_offset,
        assemblies: assembly_data,
        unknown1: unknown1,
        unknown2: unknown2,
        unknown3: unknown3,
        zeroes: zeroes
      }
    end
  end
  def parse_assembly_data(data) do
    << 
      start_read::little-integer-size(16),
      counter_1::little-integer-size(16),
      x::little-integer-size(16),
      y::little-integer-size(16),
      maybe_just_zero::little-integer-size(16),
      end_read::little-integer-size(16),
      counter_2::little-integer-size(16),
      end_x::little-integer-size(16),
      end_y::little-integer-size(16),
      mbalso_just_zero::little-integer-size(16)
    >> = data
      |> :erlang.list_to_binary()

    %{
      start_read: start_read,
      counter_1: counter_1,
      x: x,
      y: y,
      maybe_just_zero: maybe_just_zero,
      end_read: end_read,
      counter_2: counter_2,
      end_x: end_x,
      end_y: end_y,
      mbalso_just_zero: mbalso_just_zero
    }
 
  end

end

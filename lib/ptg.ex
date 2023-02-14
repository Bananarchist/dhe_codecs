defmodule Ptg do
  @behaviour Identification

  @magic_number << 0x50, 0x54, 0x47, 0x40 >>

  @impl Identification
  def is?(input) do
    << 
      magic_number::bitstring-size(32),
      _rest
    >> = input
    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "ptg"


  def parse_ptg(stream) do
    <<
      magic_number::bitstring-size(32),
      assembly_offset::little-integer-size(32),
      ptx1_offset::little-integer-size(32),
      ptx2_offset::little-integer-size(32),
      unknown1::little-integer-size(16), # these correlate in someway to the PTXs I just haven't
      unknown2::little-integer-size(16), # yet identifies how
      ptx1_assembly_count::little-integer-size(16),
      ptx2_assembly_count::little-integer-size(16),
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
        |> Stream.take(0x14 * (ptx1_assembly_count + ptx2_assembly_count))
        |> Stream.chunk_every(0x14, 0x14, :discard)
        |> Enum.map(&parse_assembly_data/1)
      info = %{ 
        assemblies: assembly_data,
        unknown1: unknown1,
        unknown2: unknown2,
        ptx1_assembly_count: ptx1_assembly_count,
        ptx2_assembly_count: ptx2_assembly_count,
        zeroes: zeroes
      }
      if ptx2_offset == 0 do
        Map.put(info, :ptxs, [Stream.drop(stream, ptx1_offset)])
      else
        info
        |> Map.put(:ptxs, 
          [
            Stream.drop(stream, ptx1_offset) |> Stream.take(ptx2_offset - ptx1_offset),
            Stream.drop(stream, ptx2_offset)
          ]
          )
      end
    end
  end
  def parse_assembly_data(data) do
    << 
      start_read::little-integer-size(16),
      counter_1::little-integer-size(16), # actually maybe read y start
      x::little-integer-size(16),
      y::little-integer-size(16),
      maybe_just_zero::little-integer-size(16),
      end_read::little-integer-size(16),
      counter_2::little-integer-size(16), # and read y end
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

  def as_png(filename) do
    stream = File.stream!(filename, [], 1)
    info = stream |> parse_ptg() |> parse_ptxs()
    
  end

  def parse_ptxs(info) do
    Map.update!(info, :ptxs, fn ptxs ->
      Enum.map(ptxs, fn ptx ->
        { ptx, Ptx.parse_ptx(ptx) }
        end)
      end)
  end

  def combine_ptxs(info) do
    
  end
    
    
end

defmodule Ptg do
  @behaviour Identification
  @behaviour Extractor

  @magic_number <<0x50, 0x54, 0x47, 0x40>>

  @impl Identification
  def is?(input) do
    <<
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input

    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "ptg"

  def parse_ptg(stream) do
    if not is?(Stream.take(stream, 0x04) |> Enum.to_list() |> :erlang.list_to_binary()) do
      {:error, "Does not appear to be a PTG file - magic number did not match"}
    else
      <<
        assembly_offset::little-integer-size(32),
        ptx1_offset::little-integer-size(32),
        ptx2_offset::little-integer-size(32),
        # these correlate in someway to the PTXs I just haven't
        unknown1::little-integer-size(16),
        # yet identifies how
        unknown2::little-integer-size(16),
        ptx1_assembly_count::little-integer-size(16),
        ptx2_assembly_count::little-integer-size(16),
        zeroes::bitstring-size(64)
      >> =
        stream
        |> Stream.drop(0x04)
        |> Stream.take(0x1C)
        |> Enum.to_list()
        |> :erlang.list_to_binary()

      assembly_data =
        stream
        |> Stream.drop(assembly_offset)
        |> Stream.take(0x14 * (ptx1_assembly_count + ptx2_assembly_count))
        |> Stream.chunk_every(0x14, 0x14, :discard)
        |> Enum.map(&parse_assembly_data/1)

      %{
        unknown1: unknown1,
        unknown2: unknown2,
        ptx1_assembly_count: ptx1_assembly_count,
        ptx2_assembly_count: ptx2_assembly_count,
        ptx1_offset: ptx1_offset,
        ptx2_offset: ptx2_offset,
        assemblies: assembly_data,
        zeroes: zeroes
      }
    end
  end

  def parse_assembly_data(data) do
    <<
      start_read::little-integer-size(16),
      # actually maybe read y start
      counter_1::little-integer-size(16),
      x::little-integer-size(16),
      y::little-integer-size(16),
      maybe_just_zero::little-integer-size(16),
      end_read::little-integer-size(16),
      # and read y end
      counter_2::little-integer-size(16),
      end_x::little-integer-size(16),
      end_y::little-integer-size(16),
      mbalso_just_zero::little-integer-size(16)
    >> =
      data
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
    info = parse_ptg(stream)
    ptx_data = parse_ptxs(stream, info)
  end

  def parse_ptxs(stream, info) do
    if info.ptx2_offset == 0 do
      ptx_stream = Stream.drop(stream, info.ptx1_offset)
      ptx_info = Ptx.parse_ptx(ptx_stream)

      ptx_data =
        Ptx.tiles(ptx_stream, ptx_info) |> Ptx.tile_rows(ptx_info) |> Ptx.image_data(ptx_info)

      %{
        assemblies: Enum.take(info.assemblies, info.ptx1_assembly_count),
        info: ptx_info,
        image_data: ptx_data
      }
    else
      ptx_stream1 =
        Stream.drop(stream, info.ptx1_offset) |> Stream.take(info.ptx2_offset - info.ptx1_offset)

      ptx_info1 = Ptx.parse_ptx(ptx_stream1)

      ptx_data1 =
        Ptx.tiles(ptx_stream1, ptx_info1) |> Ptx.tile_rows(ptx_info1) |> Ptx.image_data(ptx_info1)

      ptx_stream2 = Stream.drop(stream, info.ptx2_offset)
      ptx_info2 = Ptx.parse_ptx(ptx_stream2)

      ptx_data2 =
        Ptx.tiles(ptx_stream2, ptx_info2) |> Ptx.tile_rows(ptx_info2) |> Ptx.image_data(ptx_info2)

      {
        %{
          assemblies: Enum.take(info.assemblies, info.ptx1_assembly_count),
          info: ptx_info1,
          image_data: ptx_data1
        },
        %{
          assemblies:
            Enum.drop(info.assemblies, info.ptx1_assembly_count)
            |> Enum.take(info.ptx2_assembly_count),
          info:
            if(ptx_info2.palette_offset == 0,
              do: Map.put(ptx_info2, :palette, ptx_info1.palette),
              else: ptx_info2
            ),
          image_data: ptx_data2
        }
      }
    end
  end

  def combine_ptxs(info) do
  end

  @impl Extractor
  def extract(data) do
    stream = :erlang.binary_to_list(data)

    case parse_ptg(stream) do
      {:error, e} ->
        {:error, e}

      info ->
        if info.ptx2_offset == 0 do
          {:ok,
           Stream.drop(stream, info.ptx1_offset) |> Enum.to_list() |> :erlang.list_to_binary()}
        else
          {:ok,
           [
             ptx1:
               Stream.drop(stream, info.ptx1_offset)
               |> Enum.take(info.ptx2_offset - info.ptx1_offset)
               |> :erlang.list_to_binary(),
             ptx2:
               Stream.drop(stream, info.ptx2_offset) |> Enum.to_list() |> :erlang.list_to_binary()
           ]}
        end
    end
  end
end

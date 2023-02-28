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
        width::little-integer-size(16),
        # yet identifies how
        height::little-integer-size(16),
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
        width: width,
        height: height,
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
      # start_read_x
      start_read::little-integer-size(16),
      # actually maybe start_read_y
      counter_1::little-integer-size(16),
      # start_write_x
      x::little-integer-size(16),
      # start_write_y
      y::little-integer-size(16),
      maybe_just_zero::little-integer-size(16),
      # end_read_x
      end_read::little-integer-size(16),
      # and end_read_y
      counter_2::little-integer-size(16),
      # end_write_x
      end_x::little-integer-size(16),
      # end_write_y
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
    ptxs = parse_ptxs(stream, info)

    Enum.map(ptxs, fn ptx -> assemble_image_data(ptx, info) end)
    |> Enum.with_index()
    |> Enum.each(fn {{palette, tile}, index} ->
      case Png.make_png
        |> Png.with_width(Tile.width(tile))
        |> Png.with_height(Tile.height(tile))
        |> Png.with_color_type(palette |> Enum.to_list)
        |> Png.execute(tile.data |> :erlang.list_to_binary) do
        {:ok, data} -> File.write("#{filename}_#{index}.png", data)
        {:error, err} -> IO.puts(err)
      end
    end)
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

      [
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
      ]
    end
  end

  def assemble_image_data(ptx, info) do
    ptx.assemblies
    |> Enum.map(fn ass ->
      Map.put(ass, :tile, Tile.slice(ptx.image_data, ass.start_read, 0, Tile.width(ptx.image_data) - ass.end_read, 0))
      # %{ ass | data: Tile.slice(ptx.image_data, ass.start_read, 0, Tile.width(ptx.image_data) - ass.end_read, 0) }
      end)
    |> Enum.chunk_by(& &1.y)
    |> Enum.map(fn [ass | rest] ->
      row = Enum.reduce([ass | rest], Tile.filler(%Tile{width: ass.x, height: Tile.height(ass.tile)}),
        fn el, acc -> 
          space_between = el.x - Tile.width(acc)
          padded = Tile.pad(el.tile, space_between, 0, 0, 0) 
          Enum.zip_with(acc, padded, &Enum.concat/2)
          |> Enum.into(%Tile{ acc | width: el.end_x, data: [] })
        end)
      Tile.pad(row, 0, 0, info.width - Tile.width(row), 0)
      end)
    |> Enum.concat()
    |> Enum.into(%Tile{width: info.width, height: info.height})
    |> (fn tile -> { ptx.info.palette, tile } end).()
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

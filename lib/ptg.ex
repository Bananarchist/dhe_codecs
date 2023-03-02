defmodule Ptg do
  @behaviour Identification
  @behaviour Extractor
  @behaviour PngProducer

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
      read_start_x::little-integer-size(16),
      read_start_y::little-integer-size(16),
      write_start_x::little-integer-size(16),
      write_start_y::little-integer-size(16),
      maybe_just_zero::little-integer-size(16),
      read_stop_x::little-integer-size(16),
      read_stop_y::little-integer-size(16),
      write_stop_x::little-integer-size(16),
      write_stop_y::little-integer-size(16),
      mbalso_just_zero::little-integer-size(16)
    >> =
      data
      |> :erlang.list_to_binary()

    %{
      read_start_x: read_start_x,
      read_start_y: read_start_y,
      write_start_x: write_start_x,
      write_start_y: write_start_y,
      maybe_just_zero: maybe_just_zero,
      read_stop_x: read_stop_x,
      read_stop_y: read_stop_y,
      write_stop_x: write_stop_x,
      write_stop_y: write_stop_y,
      mbalso_just_zero: mbalso_just_zero
    }
  end

  @impl PngProducer
  def to_png(filename) do
    stream = File.stream!(filename, [], 1)
    info = parse_ptg(stream)
    ptxs = parse_ptxs(stream, info)
    output_file_name = Path.basename(filename, "." <> extension()) <> ".png"

    {palette, tile} = assemble_image_data(ptxs, info)

    case Png.make_png()
         |> Png.with_width(Tile.width(tile))
         |> Png.with_height(Tile.height(tile))
         |> Png.with_color_type(palette |> Enum.to_list())
         |> Png.execute(tile.data |> :erlang.list_to_binary()) do
      {:ok, data} ->
        case File.write(output_file_name, data) do
          :ok -> {:ok, data}
          err -> err
        end

      {:error, err} ->
        IO.puts(err)
    end
  end

  def parse_ptxs(stream, info) do
    if info.ptx2_offset == 0 do
      ptx_stream = Stream.drop(stream, info.ptx1_offset)
      ptx_info = Ptx.parse_ptx(ptx_stream)
      ptx_palette = Ptx.get_palette(ptx_stream, ptx_info)
      ptx_data =
        Ptx.tiles(ptx_stream, ptx_info) |> Ptx.tile_rows(ptx_info) |> Ptx.image_data(ptx_info)

      %{
        assemblies:
          Enum.take(info.assemblies, info.ptx1_assembly_count) |> Enum.map(fn a -> {a, 0} end),
        info: {ptx_info},
        image_data: {ptx_data},
        palette: ptx_palette
      }
    else
      ptx_stream1 =
        Stream.drop(stream, info.ptx1_offset) |> Stream.take(info.ptx2_offset - info.ptx1_offset)

      ptx_info1 = Ptx.parse_ptx(ptx_stream1)

      ptx_data1 =
        Ptx.tiles(ptx_stream1, ptx_info1) |> Ptx.tile_rows(ptx_info1) |> Ptx.image_data(ptx_info1)

      ptx_palette = Ptx.get_palette(ptx_stream1, ptx_info1)

      ptx_stream2 = Stream.drop(stream, info.ptx2_offset)
      ptx_info2 = Ptx.parse_ptx(ptx_stream2)

      ptx_data2 =
        Ptx.tiles(ptx_stream2, ptx_info2) |> Ptx.tile_rows(ptx_info2) |> Ptx.image_data(ptx_info2)

      assemblies =
        Enum.split(info.assemblies, info.ptx1_assembly_count)
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.map(fn {asses, idx} -> Enum.map(asses, fn a -> {a, idx} end) end)
        |> List.flatten()

      info = {ptx_info1, ptx_info2}
      image_data = {ptx_data1, ptx_data2}

      %{
        assemblies: assemblies,
        info: info,
        image_data: image_data,
        palette: ptx_palette
      }
    end
  end

  def assemble_image_data(ptx, info) do
    ptx.assemblies
    |> Enum.map(fn {ass, data_idx} ->
      image_data = elem(ptx.image_data, data_idx)

      tile =
        Tile.slice(
          image_data,
          ass.read_start_x,
          ass.read_start_y,
          Tile.width(image_data) - ass.read_stop_x,
          Tile.height(image_data) - ass.read_stop_y
        )

      {Map.put(ass, :tile, tile), data_idx}
    end)
    |> Enum.group_by(&elem(&1, 0).write_start_y)
    |> Enum.to_list()
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {_y, row} -> Enum.sort_by(row, &elem(&1, 0).write_start_x) end)
    |> Enum.map(fn [{ass, ass_data_idx} | rest] ->
      row =
        Enum.reduce(
          [{ass, ass_data_idx} | rest],
          Tile.filler(%Tile{width: ass.write_start_x, height: Tile.height(ass.tile)}),
          fn {el, _data_idx}, acc ->
            if el.write_start_x == 0 do
              el.tile
            else
              space_between = el.write_start_x - Tile.width(acc)
              padded = Tile.pad(el.tile, space_between, 0, 0, 0)

              Enum.zip_with(acc, padded, &Enum.concat/2)
              |> Enum.into(%Tile{acc | width: el.write_stop_x, data: []})
            end
          end
        )

      Tile.pad(row, 0, 0, info.width - Tile.width(row), 0)
    end)
    |> Enum.concat()
    |> Enum.into(%Tile{width: info.width, height: info.height})
    |> (fn tile -> {ptx.palette, tile} end).()
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

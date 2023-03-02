defmodule Ptx do
  import Bitwise
  @behaviour Identification

  @magic_number <<0x50, 0x54, 0x58, 0x40>>

  @impl Identification
  def is?(input) do
    <<
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input

    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "ptx"

  def parse_ptx(stream) do
    <<
      magic_number::bitstring-size(32)
    >> =
      stream
      |> Enum.take(0x04)
      |> :erlang.list_to_binary()

    if magic_number != @magic_number do
      {:error, "Does not appear to be a PTX file - magic number did not match"}
    else
      <<
        unknown_short1::little-integer-size(16),
        width::little-integer-size(16),
        utilized_width::little-integer-size(16),
        height::little-integer-size(16),
        indexing::little-integer-size(8),
        unknown_short2::bitstring-size(16),
        channel_ordering::bitstring-size(8),
        colors::little-integer-size(32),
        unknown_char2::little-integer-size(8),
        unknown_short3::bitstring-size(16),
        unknown_char3::little-integer-size(8),
        palette_offset::little-integer-size(32),
        data_offset::little-integer-size(32)
      >> =
        stream
        |> Stream.drop(0x04)
        |> Enum.take(0x1C)
        |> :erlang.list_to_binary()

      unknowns = %{
        addr_0x04: unknown_short1,
        addr_0x0D: unknown_short2,
        addr_0x14: unknown_char2,
        addr_0x15: unknown_short3,
        addr_0x17: unknown_char3
      }

      %{
        palette_offset: palette_offset,
        colors: colors,
        channel_ordering: channel_ordering,
        width: width,
        utilized_width: utilized_width,
        height: height,
        indexing: indexing,
        data_offset: data_offset,
        unknowns: unknowns
      }
    end
  end

  def nibble_indexing(info) do
    case info.indexing do
      4 -> true
      _ -> false
    end
  end

  def tiles(stream, info) do
    tile_width = if nibble_indexing(info), do: 32, else: 16

    data_length =
      if nibble_indexing(info),
        do: (info.width * info.height) >>> 1,
        else: info.width * info.height

    data =
      stream
      |> Stream.drop(info.data_offset)
      |> Stream.take(data_length)
      |> Stream.chunk_every(0x80)
      |> Stream.map(fn tile ->
        nibble_stream(tile, info)
        |> Enum.into(%Tile{width: tile_width, height: 8})
      end)
      |> Enum.to_list()

    data
  end

  def tile_rows(tiles, info) do
    tiles
    |> Enum.chunk_while(
      [],
      fn el, acc ->
        res = [el | acc]

        if Tile.width(el) * Enum.count(res) >= info.width do
          {:cont,
           Enum.reverse([el | acc])
           |> Enum.zip_with(&Enum.concat/1)
           |> Enum.into(%Tile{width: info.width, height: 8}), []}
        else
          {:cont, res}
        end
      end,
      fn acc -> {:cont, acc} end
    )
  end

  def image_data(tile_rows, info) do
    Enum.reduce(tile_rows, %Tile{width: info.width, height: info.height}, &Enum.into/2)
  end

  def get_palette(stream, info, fallback \\ []) do
    if info.palette_offset == 0 do
      fallback
    else
      stream
      |> Stream.drop(info.palette_offset)
      |> Stream.take(info.colors * 0x04)
      |> Stream.chunk_every(0x04)
      |> Enum.to_list
    end
  end

  def as_png(input_file_name),
    do:
      as_png(
        input_file_name,
        Path.join([
          Path.dirname(input_file_name),
          Path.basename(input_file_name, ".ptx") <> ".png"
        ])
      )

  def as_png(input_file_name, output_file_name) do
    stream = File.stream!(input_file_name, [], 1)
    info = parse_ptx(stream)
    as_png(stream, info, output_file_name)
  end

  def as_png(stream, info, file_name) do
    conditionally_bgra = 
    image_tile =
      stream
      |> tiles(info)
      |> tile_rows(info)
      |> image_data(info)

    case Png.make_png()
         |> Png.with_width(info.width)
         |> Png.with_height(info.height)
         |> Png.with_color_type(get_palette(stream, info) |> Enum.to_list())
         |> reorder_channels(info)
         |> Png.execute(image_tile.data |> :erlang.list_to_binary()) do
      {:ok, png_data} -> File.write(file_name, png_data <> <<>>)
      {:error, err} -> IO.puts(err)
    end
  end

  def nibble_stream(stream, info) do
    if nibble_indexing(info) do
      Stream.map(stream, fn byte ->
        <<
          nib2::little-integer-size(4),
          nib1::little-integer-size(4)
        >> = byte

        [nib1, nib2]
      end)
    else
      stream
    end
  end

  def reorder_channels(png, info) do
    case info.channel_ordering do
      0x08 -> Png.with_bgra(png)
      _ -> png
    end
  end
end

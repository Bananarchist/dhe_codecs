defmodule Lim do
  import Bitwise
  @moduledoc """
  A module for faciliating working with LIM graphic files
  """

  def parse_lim(stream) do
    offsets = parse_file(stream)
    structural_data = parse_structure_data(stream, offsets.structural_data_offset)
    palette_data = parse_palette_data(stream, offsets.palette_header_offset)
    assemblies = parse_assemblies(stream)
    height = 
      assemblies
      |> Enum.max_by(&(&1.image_y))
      |> (&(&1.image_y + 16)).()
    width = 
      assemblies
      |> Enum.max_by(&(&1.image_x + (&1.read_length <<< 4)))
      |> (&(&1.image_x + (&1.read_length <<< 4))).()

    %{
      offsets: offsets,
      assemblies: assemblies,
      palette_data: palette_data,
      structure_data: structural_data,
      palette_count: palette_data.colors >>> 8,
      width: width,
      height: height
    }
      
  end

  def parse_assemblies(stream) do
    <<
      assembly_count::little-integer-size(32),
      assembly_data_offset::little-integer-size(32)
    >> = stream
      |> Stream.take(0x08)
      |> Enum.to_list
      |> :erlang.list_to_binary

    assemblies =
      stream
      |> Stream.drop(assembly_data_offset)
      |> Stream.take(assembly_count * 0x0C)
      |> Stream.chunk_every(0x0C)
      |> Enum.map(&parse_assembly_data/1)

    min_y = Enum.min_by(assemblies, &(&1.image_y)).image_y
    min_x = 0 #Enum.min_by(assemblies, &(&1.image_x)).image_x

    Enum.map(assemblies, fn a -> %{ a | image_y: a.image_y - min_y, image_x: a.image_x - min_x } end)
  end

  def parse_file(stream) do
    <<
      assembly_data_offset::little-integer-size(32),
      assembly_end::little-integer-size(32)
    >> = stream
      |> Stream.drop(0x04)
      |> Stream.take(0x08)
      |> Enum.to_list
      |> :erlang.list_to_binary

    <<
      structural_data_offset::little-integer-size(32),
      palette_header_offset::little-integer-size(32),
    >> = stream
      |> Stream.drop(assembly_end)
      |> Stream.take(0x8)
      |> Enum.to_list
      |> :erlang.list_to_binary

    <<
      tile_data_offset::little-integer-size(32)
    >> = stream
        |> Stream.drop(structural_data_offset + 0x08)
        |> Stream.take(0x04)
        |> Enum.to_list
        |> :erlang.list_to_binary

    <<
      palette_data_offset::little-integer-size(32)
    >> = stream
      |> Stream.drop(palette_header_offset + 0x04)
      |> Stream.take(0x4)
      |> Enum.to_list
      |> :erlang.list_to_binary

    %{
      assembly_data_offset: assembly_data_offset,
      structural_data_offset: structural_data_offset,
      palette_header_offset: palette_header_offset,
      palette_data_offset: palette_data_offset,
      tile_data_offset: tile_data_offset
    }
  end

  def parse_header(stream) do
    <<
    assemblies::little-integer-size(32),
    assembly_data_offset::little-integer-size(32),
    structure_data_offset::little-integer-size(32)
    >> = stream
        |> Stream.take(0x0C)
        |> Enum.to_list
        |> :erlang.list_to_binary
    %{
      assemblies: assemblies,
      assembly_data_offset: assembly_data_offset,
      structure_data_offset: structure_data_offset
    }
  end
  def parse_structure_data(stream, structural_data_offset) do
    <<
      tile_size::little-integer-size(16),
      tile_partitions::little-integer-size(16),
      block_size::little-integer-size(16),
      unknown1::little-integer-size(16),
      _tile_data_offset::little-integer-size(32),
      unknown2::little-integer-size(16),
      unknown3::little-integer-size(16),
      just_zero::little-integer-size(32),
    >> = stream
      |> Stream.drop(structural_data_offset)
      |> Stream.take(0x14)
      |> Enum.to_list
      |> :erlang.list_to_binary


    %{ 
      tile_size: tile_size,
      tile_partitions: tile_partitions,
      block_size: block_size,
      unknown1: unknown1,
      unknown2: unknown2,
      unknown3: unknown3,
      just_zero: just_zero,
    }
  end

  def parse_palette_data(stream, palette_header_offset) do
    <<
      colors::little-integer-size(16),
      color_mode::little-integer-size(16),
      palette_offset::little-integer-size(32)
    >> = stream
      |> Stream.drop(palette_header_offset)
      |> Stream.take(0x8)
      |> Enum.to_list
      |> :erlang.list_to_binary

    %{
      colors: colors,
      color_mode: color_mode,
      palettes: parse_palette(stream, palette_offset)
    }
  end

  def parse_assembly_data(stream) do
    <<
     tile_counter::little-integer-size(16), 
     block_counter::little-integer-size(16), 
     image_x::little-integer-size(16), 
     image_y::little-integer-size(16), 
     read_length::little-integer-size(16), 
     tile_length::little-integer-size(16)
    >> = stream
         |> Enum.take(0x0C)
         |> Enum.to_list
         |> :erlang.list_to_binary
    %{
      :tile_counter => tile_counter >>> 4,
      :block_counter => block_counter >>> 4,
      :image_y => image_y,
      :image_x => image_x,
      :read_length => read_length >>> 4,
      :tile_length_in_pixels => tile_length,
    }
  end

  defp stream_of_zeros do
    Stream.repeatedly(fn -> <<0>> end)
  end
  defp stream_of_zeros(count) do
    stream_of_zeros()
    |> Stream.take(count)
  end

  def pixel_data(stream, info) do
      chunk_pixel_data(stream, info)
      |> assembly_rows(info)
      |> merge_pixelated_assemblies_on_image_y(info)
      |> List.flatten
      |> :erlang.list_to_binary
  end

  def aa_to_png(), do: lim_to_png("output/bustup/bu_m_30.lim")
  def lim_to_png(), do: lim_to_png("output/bustup/0308.lim")
  def lim_to_png(filename) do
    stream = File.stream!(filename, [], 1)
    info = parse_lim(stream)
    pixel_data = pixel_data(stream, info)

    case Png.make_png
      |> Png.with_width(info.width)
      |> Png.with_height(info.height)
      |> Png.with_color_type(info.palette_data.palettes |> Enum.to_list()) # need to actually handle multiple palettes someday~
      |> Png.execute(pixel_data)
        do
          {:ok, png_data} -> File.write(file_name, png_data <> <<>>)
          {:error, err} -> IO.puts(err)
        end
    
  end

  defp in_tiles(pixel_count), do: pixel_count >>> 4
  defp in_pixels(tile_count), do: tile_count <<< 4

  def export_tiles(file_name) do
    stream = File.stream!(file_name, [], 1)
    info = parse_lim(stream)
    bs = chunk_pixel_data(stream, info)
    Enum.with_index(bs)
    |> Enum.each(fn {block, block_idx} ->
      Enum.with_index(block)
      |> Enum.each(fn {tile, tile_idx} ->
        unless tile |> List.flatten |> Enum.count == 256 do
          IO.puts("massive failure")
        end
        case Png.make_png
          |> Png.with_width(16)
          |> Png.with_height(16)
          |> Png.with_color_type(info.palette_data.palettes |> Enum.to_list())
          |> Png.execute(tile |> List.flatten |> :erlang.list_to_binary) do
          {:ok, png_data} -> File.write("output/output_#{block_idx}_#{tile_idx}.png", png_data <> <<>>)
          {:error, err} -> IO.puts(err)
        end
      end)
    end)
  end

  def pixelated_assembly_list_merger([only | []], info) do
    skip = only.image_x
    remainder = info.width - skip - in_pixels(only.read_length)
    pad_left = skip
               |> stream_of_zeros
               |> Enum.to_list
               |> :erlang.list_to_binary
    # I don't understand this +1
    pad_right = remainder + 1
                |> stream_of_zeros
                |> Enum.to_list
                |> :erlang.list_to_binary
    IO.inspect({only.image_y, skip, in_pixels(only.read_length), remainder, skip + in_pixels(only.read_length) + remainder, only.tiles |> Enum.count})
    Enum.zip(only.tiles) 
      |> Enum.map(fn row -> 
        pixel_row = 
          row 
          |> Tuple.to_list() 
          |> List.flatten 
          |> :erlang.list_to_binary
        pad_left <> pixel_row <> pad_right
      end)
  end

  def pixelated_assembly_list_merger([first | [ second | remaining] ], info) do
    start = first.image_x
    end_of_start = start + in_pixels(first.read_length)
    filler = second.image_x - end_of_start
    between_first_and_second = stream_of_zeros(filler * 16) |> Stream.chunk_every(16) |> Enum.to_list() |> Enum.chunk_every(16)
    tiles = Enum.concat([first.tiles, between_first_and_second, second.tiles])
    new_read_length = in_tiles(second.image_x - start + in_pixels(second.read_length))
    new_map = %{ first | tiles: tiles, read_length: new_read_length }
    pixelated_assembly_list_merger([new_map | remaining], info)
  end

  def merge_pixelated_assemblies_on_image_y(assembly_tiles, info) do
      assembly_tiles
      |> Enum.chunk_by(&(&1.image_y))
      |> Enum.map(fn tile_row -> Enum.sort_by(tile_row, &(&1.image_x)) end)
      |> Enum.map(&pixelated_assembly_list_merger(&1, info))
  end

  def assembly_rows(blocked_tile_stream, info) do
    info.assemblies
    |> Enum.map(&Map.put(&1, :tiles, assembly_tiles(blocked_tile_stream, info, &1)))
  end

  def dev_shortcut(filename) do
    stream = File.stream!(filename, [], 1)
    info = parse_lim(stream)
    bs = chunk_pixel_data(stream, info)
    ass_rows = assembly_rows(bs, info)
    {info, bs, ass_rows}
  end
    
  def assembly_tiles(blocked_tile_stream, _info, assembly) do
    blocked_tile_stream
    |> get_block(assembly.block_counter)
    |> Enum.to_list()
    |> List.first()
    |> get_tiles(assembly.tile_counter, assembly.read_length)
    |> Enum.to_list()
  end

  @doc """ 
  Chunk into pixel rows
  Chunk into sets of pixel rows (tile fragments)
  Chunk into blocks
  For each block:
    Split in half
    Zip halves (put tile fragments with their partners)
    Flatten tuple of tile fragments to a tile's set of pixel rows
  """
  def chunk_pixel_data(file_stream, info) do
    blocked_pixel_data =
      file_stream
      |> seek_to(info.offsets.tile_data_offset)
      |> Stream.take(info.offsets.palette_data_offset - info.offsets.tile_data_offset)
      |> Stream.chunk_every(0x10)
      |> Stream.chunk_every(0x08)
      |> Stream.chunk_every(0x40)
      |> Enum.to_list

    blocked_pixel_data
      |> Enum.with_index
      |> Enum.map(fn {block, idx} ->
        if idx == (Enum.count(blocked_pixel_data) - 1) do
          remainder = 0x40 - Enum.count(block)
          padding = stream_of_zeros(remainder * 0x80) |> Enum.chunk_every(0x10) |> Enum.chunk_every(0x08)
          block ++ padding
        else
          block
        end
        |> Enum.chunk_every(0x20)
        |> Enum.zip_with(&Enum.concat/1)
      end)
  end

  defp seek_to(stream, offset), do: Stream.drop(stream, offset)
  defp get_block(stream, block_counter), do: Stream.drop(stream, block_counter) |> Stream.take(1) 
  defp get_tiles(stream, tile_counter, read_length), do: Stream.drop(stream, tile_counter) |> Stream.take(read_length)

  defp chunk_tiles(stream), do: Stream.chunk_every(stream, 0x10) |> Stream.chunk_every(0x08) 

  def parse_palette(stream, offset) do
    stream
    |> Stream.drop(offset)
    |> Stream.take(0x400)
    |> Stream.chunk_every(0x4)
  end
end

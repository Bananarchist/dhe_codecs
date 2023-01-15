defmodule Tpl do
  # format - 0x04 = nibble pixels, 0x05 = byte pixels, 0xFFFF = sprite assembly data
  @behaviour PngProducer
  import Bitwise

  def info(file_name) do
    parse_tpl(File.stream!(file_name, [], 1))
  end

  def parse_tpl(stream) do
    <<
      texture_count::little-integer-size(32),
      texture_header_offset::little-integer-size(32)
    >> =
      stream
      |> Stream.take(0x08)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

    parse_textures(stream, texture_header_offset, texture_count)
  end

  def parse_textures(stream, texture_header_offset, texture_count) do
    textures =
      stream
      |> Stream.drop(texture_header_offset)
      |> Stream.take(0x08 * texture_count)
      |> Stream.chunk_every(0x08)
      |> Stream.map(fn data ->
        <<
          tdo::little-integer-size(32),
          pdo::little-integer-size(32)
        >> = data |> :erlang.list_to_binary()

        if pdo == 0 do
          %{
            texture: parse_texture_data(stream, tdo)
          }
        else
          %{
            texture: parse_texture_data(stream, tdo),
            palette: parse_palette_data(stream, pdo)
          }
        end
      end)
      |> Enum.to_list()

    if Enum.any?(textures, &(&1.texture.format == 0xFFFF)) do
      Enum.split_with(textures, &(&1.texture.format == 0xFFFF))
      |> get_sprite_data(stream)
    else
      textures
    end
  end

  def get_sprite_data({sprites, [texture | []]}, stream),
    do: get_sprite_data(sprites, texture, stream)

  def get_sprite_data({sprites, [texture | _others]}, stream) do
    IO.puts(
      "Encountered TPL with sprite data and multiple textures! Proceeding as if other textures do not exist..."
    )

    get_sprite_data(sprites, texture, stream)
  end

  def get_sprite_data(sprites, texture, stream) when is_list(sprites) do
    Enum.map(sprites, fn sprite ->
      <<
        _sprite_header::little-integer-size(32),
        sprite_count::little-integer-size(32)
      >> =
        stream
        |> Stream.drop(sprite.texture.offset)
        |> Stream.take(0x08)
        |> Enum.to_list()
        |> :erlang.list_to_binary()

      sprite_data =
        stream
        |> Stream.drop(sprite.texture.offset + 0x08)
        |> Stream.take(sprite_count * 0x08)
        |> Stream.chunk_every(0x08)
        |> Enum.map(&parse_sprite_header(&1, stream |> Stream.drop(sprite.texture.offset)))

      %{
        texture: texture,
        olde: sprite.texture,
        sprites: sprite_data
      }
    end)
  end

  def parse_sprite_header(data, stream) do
    <<
      offset::little-integer-size(32),
      unknown1::little-integer-size(8),
      bytes::little-integer-size(16),
      count::little-integer-size(8)
    >> = data |> :erlang.list_to_binary()

    assemblies =
      stream
      |> Stream.drop(offset)
      |> Stream.take(count * 0x06)
      |> Stream.chunk_every(0x06)
      |> Enum.map(&parse_assembly_data/1)

    if Enum.count(assemblies) == 0 do
      IO.puts("Assembly list at #{offset} was empty")
    end

    width =
      assemblies
      |> Enum.map(&(&1.dest_x + &1.width))
      |> Enum.max()

    height =
      assemblies
      |> Enum.max_by(& &1.dest_y)
      |> (fn x -> x.dest_y + x.height end).()

    %{
      offset: offset,
      unknown1: unknown1,
      bytes: bytes,
      count: count,
      assemblies: assemblies,
      width: width,
      height: height
    }
  end

  def parse_assembly_data(data) do
    <<
      hShift::little-integer-size(8),
      vShift::little-integer-size(8),
      # x::little-integer-size(10),
      # y::little-integer-size(6),
      source_coords::little-integer-size(16),
      width::little-integer-size(8),
      height::little-integer-size(8)
    >> = data |> IO.inspect |> :erlang.list_to_binary()
    # can't figure out how to do this just as a part of the above
    <<y::integer-size(6), x::integer-size(10)>> = <<source_coords::size(16)>>

    %{
      dest_x: hShift,
      dest_y: vShift <<< 1,
      source_y: y <<< 3,
      source_x: x,
      width: width,
      height: height >>> 2
    }
  end

  def parse_texture_data(stream, texture_data_offset) do
    stream
    |> Stream.drop(texture_data_offset)
    |> Stream.take(0x0C)
    |> Stream.chunk_every(0x0C)
    |> Stream.map(&parse_texture_data_header/1)
    |> Enum.to_list()
    |> List.first()
  end

  def parse_palette_data(stream, palette_data_offset) do
    stream
    |> Stream.drop(palette_data_offset)
    |> Stream.take(0x08)
    |> Stream.chunk_every(0x08)
    |> Stream.map(&parse_palette_data_header/1)
    |> Enum.to_list()
    |> List.first()
  end

  def parse_texture_data_header(data) do
    # there are actually 8bytes more of unknown data assoc with textures
    <<
      height::little-integer-size(16),
      unknown::little-integer-size(16),
      width::little-integer-size(16),
      format::little-integer-size(16),
      offset::little-integer-size(32)
    >> = data |> :erlang.list_to_binary()

    %{
      height: height,
      width: width,
      unknown: unknown,
      format: format,
      offset: offset
    }
  end

  def parse_palette_data_header(data) do
    <<
      colors::little-integer-size(16),
      mode::little-integer-size(16),
      offset::little-integer-size(32)
    >> = data |> :erlang.list_to_binary()

    %{
      colors: colors,
      mode: mode,
      offset: offset
    }
  end

  def assemble_texture_array(stream, texture, read_length) do
    stream
    |> Stream.drop(texture.offset)
    |> Stream.take(read_length)
    |> Enum.chunk_every(0x10)
    |> Enum.chunk_every(0x8)
    |> Enum.chunk_every(
      texture.width >>>
        if texture.format == 4 do
          5
        else
          4
        end
    )
    |> Enum.map(fn x -> Enum.zip_with(x, &Function.identity/1) end)
    |> Enum.to_list()
    |> List.flatten()
    |> nibble(texture.format)
  end

  def tile_of_zeroes(width, height) when width > 0 do
    Stream.repeatedly(fn -> <<0>> end)
    |> Enum.take(width * height)
    |> Enum.chunk_every(width)
  end

  def tile_of_zeroes(_, height) when height > 0 do
    Stream.repeatedly(fn -> [] end)
    |> Enum.take(height)
  end

  @spec merge_pixelated_assemblies_on_dest_y([Map.t()], integer) :: Map.t()
  def merge_pixelated_assemblies_on_dest_y([first | [second | rest]], width) do
    empty_space = second.dest_x - (first.dest_x + first.width)
    filler_pixels = tile_of_zeroes(empty_space, first.height)

    pixel_data =
      Enum.zip_with([first.pixel_data, filler_pixels, second.pixel_data], &Enum.concat/1)

    [%{first | pixel_data: pixel_data, width: first.width + empty_space + second.width} | rest]
    |> merge_pixelated_assemblies_on_dest_y(width)
  end

  def merge_pixelated_assemblies_on_dest_y([ass | []], width) do
    pad_left = tile_of_zeroes(ass.dest_x, ass.height)
    pad_right = tile_of_zeroes(width - (ass.dest_x + ass.width), ass.height)

    %{
      dest_y: ass.dest_y,
      height: ass.height,
      pixel_data: Enum.zip_with([pad_left, ass.pixel_data, pad_right], &Enum.concat/1)
    }
  end

  @spec merge_sprite_assembly_rows([Map.t()], integer) :: [[binary]]
  def merge_sprite_assembly_rows([ass | []], width) do
    pad_top =
      if ass.dest_y > 0 do
        tile_of_zeroes(ass.dest_y, width)
      else
        []
      end

    Enum.concat([pad_top, ass.pixel_data])
  end

  def merge_sprite_assembly_rows([first | [second | rest]], width) do
    empty_space = second.dest_y - (first.dest_y + first.height)

    pixel_data =
      if empty_space > 0 do
        Enum.concat([first.pixel_data, tile_of_zeroes(empty_space, width), second.pixel_data])
      else
        Enum.concat([first.pixel_data, second.pixel_data])
      end

    merge_sprite_assembly_rows(
      [
        %{
          first
          | height: first.height + empty_space + second.height,
            pixel_data: pixel_data
        }
        | rest
      ],
      width
    )
  end

  @spec assembly_with_pixel_data(Map.t(), [[binary]]) :: Map.t()
  def assembly_with_pixel_data(assembly, texture_rows) do
    pixel_data =
      texture_rows
      |> Enum.drop(assembly.source_y)
      |> Enum.take(assembly.height)
      |> Enum.map(fn row ->
        row
        |> Enum.drop(assembly.source_x)
        |> Enum.take(assembly.width)
      end)

    Map.put(assembly, :pixel_data, pixel_data)
  end

  @spec assemble_sprite(Map.t(), [[binary]], integer) :: [[binary]]
  def assemble_sprite(sprite, texture_array, texture_width) do
    texture_rows =
      texture_array
      |> :erlang.list_to_binary()
      |> :binary.bin_to_list()
      |> Enum.chunk_every(texture_width)

    sprite.assemblies
    |> Enum.map(&assembly_with_pixel_data(&1, texture_rows))
    |> Enum.chunk_by(& &1.dest_y)
    |> Enum.map(&merge_pixelated_assemblies_on_dest_y(&1, sprite.width))
    |> merge_sprite_assembly_rows(sprite.width)
  end

  @spec assemble_sprite_sheet([Map.t()], [[binary]], integer) :: binary
  def assemble_sprite_sheet(sprites, texture_array, texture_width) do
    max_width = sprites |> Enum.map(& &1.width) |> Enum.max()
    max_height = sprites |> Enum.map(& &1.height) |> Enum.max()

    sprites
    |> Enum.with_index()
    |> Enum.map(fn {sprite, idx} ->
      pixel_data = assemble_sprite(sprite, texture_array, texture_width)
      height = sprite.height
      width = sprite.width

      %{
        pixel_data: pixel_data,
        height: height,
        width: width,
        dest_x: max_width - width,
        dest_y: (max_height + 1) * idx + (max_height + 1 - height)
        # there is a pattern emerging here around combining tiles
      }
    end)
    |> Enum.reduce([], fn sprite, acc ->
      pad_left = tile_of_zeroes(sprite.dest_x, sprite.height)
      pad_bottom = tile_of_zeroes(max_width, 1)

      Enum.zip_with([pad_left, sprite.pixel_data], &Enum.concat/1)
      |> Enum.concat(pad_bottom)
      |> (fn s -> Enum.concat(acc, s) end).()
    end)
    |> List.flatten()
    |> :erlang.list_to_binary()
  end

  def is_sprite?(info) when is_list(info), do: is_sprite?(List.first(info))
  def is_sprite?(info) when is_map(info), do: Map.has_key?(info, :olde)
  def is_sprite?(_), do: false

  def as_png(input_file_name), do: as_png(input_file_name, Path.basename(input_file_name, ".tpl"))

  def as_png(input_file_name, base_output_file_name) do
    output_file_name = base_output_file_name
    stream = File.stream!(input_file_name, [], 1)

    stream
    |> parse_tpl()
    |> Enum.with_index()
    |> Enum.each(fn {texture, idx} ->
      as_png(stream, texture, output_file_name <> Integer.to_string(idx) <> ".png")
    end)
  end

  @spec as_png(Stream.t(), Map.t(), String.t(), boolean) :: {:ok, binary} | {:error, String.t()}
  def as_png(stream, info, file_name, make_spritesheet \\ true) do
    if make_spritesheet and is_sprite?(info) do
      # this assumes palettes always succeed textures...!
      total_bytes = info.texture.palette.offset - info.texture.texture.offset
      max_height = info.sprites |> Enum.map(& &1.height) |> Enum.max()
      height = (max_height + 1) * Enum.count(info.sprites)
      width = info.sprites |> Enum.map(& &1.width) |> Enum.max()
      palette_data = get_palette(stream, info.texture.palette.offset, info.texture.palette.colors)

      texture_data =
        assemble_texture_array(stream, info.texture.texture, total_bytes)
        |> List.flatten()

      pixel_data = assemble_sprite_sheet(info.sprites, texture_data, info.texture.texture.width)

      make_png(palette_data, pixel_data, width, height, file_name)
    else
      info = 
        if is_sprite?(info) do
          List.first(info).texture
        end
      density_shift =
        if info.texture.format == 4 do
          1
        else
          0
        end

      # this assumes palettes always succeed textures...!
      total_bytes = info.palette.offset - info.texture.offset

      height =
        case Integer.floor_div(total_bytes <<< density_shift, info.texture.width) do
          h when h < info.texture.height -> h
          _ -> info.texture.height
        end

      palette_data = get_palette(stream, info.palette.offset, info.palette.colors)

      pixel_data =
        assemble_texture_array(stream, info.texture, total_bytes)
        |> :erlang.list_to_binary()

      make_png(palette_data, pixel_data, info.texture.width, height, file_name)
    end
  end

  @spec get_palette(Stream.t(), integer, integer) :: [binary]
  def get_palette(stream, offset, colors) do
    stream
    |> Stream.drop(offset)
    |> Stream.take(colors * 0x04)
    |> Stream.chunk_every(0x04)
    |> Enum.to_list()
  end

  @spec make_png([binary], binary, integer, integer, String.t()) :: {:ok, binary} | {:error, String.t()}
  def make_png(palette_data, pixel_data, width, height, file_name) do
    case Png.make_png()
         |> Png.with_width(width)
         |> Png.with_height(height)
         |> Png.with_color_type(palette_data)
         |> Png.execute(pixel_data) do
      {:ok, png_data} ->
        case File.write(file_name, png_data <> <<>>) do
          :ok -> {:ok, png_data}
          err -> err
        end

      err ->
        err
    end
  end

  def flip_nibbles(byte) do
    <<
      nib2::little-integer-size(4),
      nib1::little-integer-size(4)
    >> = byte

    <<nib1, nib2>>
  end

  def nibble(enum, indexing) do
    if indexing == 4 do
      Enum.map(enum, &flip_nibbles/1)
    else
      enum
    end
  end

  @impl PngProducer
  def to_png(file_name) do
    as_png(file_name)
  end
end

defmodule Tpl do
  # format - 0x04 = nibble pixels, 0x05 = byte pixels, 0xFFFF = sprites or something

  def parse_tpl(stream) do
    <<
      texture_count::little-integer-size(32),
      texture_header_offset::little-integer-size(32)
    >> =
      stream
      |> Stream.take(0x08)
      |> Enum.to_list
      |> :erlang.list_to_binary

    parse_textures(stream, texture_header_offset, texture_count)
  end

  def parse_textures(stream, texture_header_offset, texture_count) do
    stream
    |> Stream.drop(texture_header_offset)
    |> Stream.take(0x08 * texture_count)
    |> Stream.chunk_every(0x08)
    |> Stream.map(fn data ->
      <<
        tdo::little-integer-size(32),
        pdo::little-integer-size(32)
      >> = data |> :erlang.list_to_binary
      %{
        texture: parse_texture_data(stream, tdo),
        palette: parse_palette_data(stream, pdo)
      }
    end)
    |> Enum.to_list
  end

  def parse_texture_data(stream, texture_data_offset) do
    stream
    |> Stream.drop(texture_data_offset)
    |> Stream.take(0x0C)
    |> Stream.chunk_every(0x0C)
    |> Stream.map(&parse_texture_data_header/1)
    |> Enum.to_list
    |> List.first
  end

  def parse_palette_data(stream, palette_data_offset) do
    stream
    |> Stream.drop(palette_data_offset)
    |> Stream.take(0x08)
    |> Stream.chunk_every(0x08)
    |> Stream.map(&parse_palette_data_header/1)
    |> Enum.to_list
    |> List.first
  end

  def parse_texture_data_header(data) do
    <<
      height::little-integer-size(16),
      width::little-integer-size(16),
      unknown::little-integer-size(16),
      format::little-integer-size(16),
      offset::little-integer-size(32)
    >> = data |> :erlang.list_to_binary

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
    >> = data |> :erlang.list_to_binary

    %{
      colors: colors,
      mode: mode,
      offset: offset
    }
  end

  def as_png(input_file_name), do: as_png(input_file_name, Path.basename(input_file_name, ".tpl"))

  def as_png(input_file_name, base_output_file_name) do
    output_file_name = Path.join([Path.dirname(input_file_name), base_output_file_name])
    stream = File.stream!(input_file_name, [], 1)

    stream
    |> parse_tpl()
    |> Stream.with_index()
    |> Stream.each(fn {texture, idx} ->
      as_png(stream, texture, output_file_name <> Integer.to_string(idx) <> ".png")
    end)
    |> Stream.run()
  end

  def as_png(stream, info, file_name) do
    palette_data =
      stream
      |> Stream.drop(info.palette.offset)
      |> Stream.take(info.palette.colors * 0x04)
      |> Stream.chunk_every(0x04)
      |> Enum.to_list()

    pixel_data =
      stream
      |> Stream.drop(info.texture.offset)
      |> nibble(info.texture.format)
      |> Stream.take(info.texture.width * info.texture.height)
      |> Enum.to_list()
      |> List.flatten()
      |> :erlang.list_to_binary

    case Png.make_png()
         |> Png.with_width(info.texture.width)
         |> Png.with_height(info.texture.height)
         |> Png.with_color_type(palette_data)
         |> Png.with_bgra()
         |> Png.execute(pixel_data) do
      {:ok, png_data} -> File.write(file_name, png_data <> <<>>)
      {:error, err} -> IO.puts(err)
    end
  end
  def nibble(stream, indexing) do
    if indexing == 4 do
      Stream.map(stream, fn byte -> 
        << 
          nib2::little-integer-size(4),
          nib1::little-integer-size(4)
        >> = byte
        [ nib1, nib2 ]
      end)
    else
      stream
    end
  end
end

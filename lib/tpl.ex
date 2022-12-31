defmodule Tpl do
  # format - 0x04 = nibble pixels, 0x05 = byte pixels, 0xFFFF = sprite assembly data
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
      |> Enum.to_list
      |> :erlang.list_to_binary

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
          >> = data |> :erlang.list_to_binary
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
        |> Enum.to_list
    if Enum.any?(textures, &(&1.texture.format == 0xFFFF)) do
      # go fetch sprite data
      # reformat texture map
      # get the texture without 0xFFFF format
      # attach it as a sub object
      Enum.split_with(textures, &(&1.texture.format == 0xFFFF))
      |> get_sprite_data(stream)
      #Enum.filter(textures, &(&1.texture.format != 0xFFFF))
      #textures
    else
      textures
    end
  end

  def get_sprite_data({sprites, [texture | []]}, stream), do: get_sprite_data(sprites, texture, stream)
  def get_sprite_data({sprites, [texture | others]}, stream) do
    IO.puts("Encountered TPL with sprite data and multiple textures! Proceeding as if other textures do not exist...")
    get_sprite_data(sprites, texture, stream)
  end
  def get_sprite_data(sprites, texture, stream) when is_list(sprites) do
    Enum.map(sprites, fn sprite ->
      <<
        _sprite_header::little-integer-size(32),
        sprite_count::little-integer-size(32)
      >> = stream
        |> Stream.drop(sprite.texture.offset)
        |> Stream.take(0x08)
        |> Enum.to_list
        |> :erlang.list_to_binary

      sprite_data = 
          stream
          |> Stream.drop(sprite.texture.offset + 0x08)
          |> Stream.take(sprite_count * 0x08)
          |> Stream.chunk_every(0x08)
          |> Enum.map(&(parse_sprite_header(&1, stream |> Stream.drop(sprite.texture.offset))))
        
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
      >> = data |> :erlang.list_to_binary

      assemblies =
        stream
        |> Stream.drop(offset)
        |> Stream.take(count * 0x06)
        |> Stream.chunk_every(0x06)
        |> Enum.map(&parse_assembly_data/1)

      width = 
        assemblies
        |> Enum.map(&(&1.hShift + &1.width))
        |> Enum.max

      height = 
        assemblies
        |> Enum.max_by(&(&1.vShift))
        |> (fn x -> x.vShift + x.height end).()


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
      row::little-integer-size(6),
      column::little-integer-size(10),
      width::little-integer-size(8),
      height::little-integer-size(8)
    >> = data |> :erlang.list_to_binary

    %{
      hShift: hShift,
      vShift: vShift <<< 1,
      row: row,
      column: column,
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
    # there are actually 8bytes more of unknown data assoc with textures
    <<
      height::little-integer-size(16),
      unknown::little-integer-size(16),
      width::little-integer-size(16),
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
    output_file_name = base_output_file_name
    stream = File.stream!(input_file_name, [], 1)

    stream
    |> parse_tpl()
    |> Enum.filter(&(Map.has_key?(&1, :palette)))
    |> Enum.with_index()
    |> Enum.each(fn {texture, idx} ->
      as_png(stream, texture, output_file_name <> Integer.to_string(idx) <> ".png")
    end)
  end

  def as_png(stream, info, file_name) do
    density = if info.texture.format == 4 do 2 else 1 end
    density_shift = density - 1
    total_bytes = info.palette.offset - info.texture.offset # this assumes palettes always succeed textures...!
    height = Integer.floor_div(total_bytes <<< density_shift, info.texture.width)
    palette_data =
      stream
      |> Stream.drop(info.palette.offset)
      |> Stream.take(info.palette.colors * 0x04)
      |> Stream.chunk_every(0x04)
      |> Enum.to_list()

    pixel_data =
      stream
      |> Stream.drop(info.texture.offset)
      |> Stream.take(total_bytes)
      |> Enum.chunk_every(0x10)
      |> Enum.chunk_every(0x8)
      |> Enum.chunk_every(info.texture.width >>> (4 <<< 0))
      |> Enum.map(fn x -> Enum.zip_with(x, &Function.identity/1) end)
      |> Enum.to_list()
      |> List.flatten()
      |> nibble(info.texture.format)
      |> :erlang.list_to_binary

    case Png.make_png()
         |> Png.with_width(info.texture.width)
         |> Png.with_height(height) 
         |> Png.with_color_type(palette_data)
         |> Png.execute(pixel_data) do
      {:ok, png_data} -> File.write(file_name, png_data <> <<>>)
      {:error, err} -> IO.puts(err)
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
end

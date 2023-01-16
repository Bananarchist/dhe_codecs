defmodule Tpl do
  # format - 0x04 = nibble pixels, 0x05 = byte pixels, 0xFFFF = sprite assembly data
  @behaviour PngProducer
  import Bitwise

  def new_palette(colors, mode, offset) do
    {:palette,
    %{ colors: colors, mode: mode, offset: offset }
    }
  end

  def new_texture(format, offset, unknown, width, height) do
    {:texture,
    %{ format: format, height: height, offset: offset, unknown: unknown, width: width }
    }
  end

  def new_sprite(bytes, assembly_count, offset, unknown, width, height) do
    new_sprite(bytes, assembly_count, offset, unknown, width, height, [])
  end
  def new_sprite(bytes, assembly_count, offset, unknown, width, height, assemblies) do
    {:sprite,
    %{ bytes: Integer.to_string(bytes, 16) |> (&("0x" <> &1)).(), count: assembly_count, offset: offset, unknown: Integer.to_string(unknown, 16) |> (&("0x" <> &1)).(), width: width, height: height, assemblies: assemblies}
    }
  end

  def new_assembly(dest_x, dest_y, src_x, src_y, width, height) do
    %{ dest_x: dest_x, dest_y: dest_y, src_x: src_x, src_y: src_y, width: width, height: height }
  end

  def with_texture(info, texture) do
    if Keyword.has_key?(info, :texture) && Keyword.has_key?(info, :sprite) do
      IO.puts("Multiple textures with assembly flags not yet supported. Secondary textures will be ignored.")
    end
    info ++ [texture]
  end

  def with_palette(info, palette) do
    if Keyword.has_key?(info, :palette) do
      IO.puts("Multiple palettes not yet supported for export.")
    end
    info ++ [palette]
  end

  def with_sprite(info, sprite) do
    info ++ [sprite]
    # Map.update(info, :sprite, [sprite], fn s -> s ++ [sprite] end)
  end

  def texture(info), do: Keyword.get(info, :texture)
  def palette(info), do: Keyword.get(info, :palette)
  def sprites(info), do: Keyword.get(info, :sprite)
  def texture_bytes(info), do: palette(info).offset - texture(info).offset

  def info(file_name) do
    parse_tpl(File.stream!(file_name, [], 1))
  end

  def parse_tpl(stream) do
    <<
      data_descriptors_count::little-integer-size(32),
      data_descriptors_offset::little-integer-size(32)
    >> =
      stream
      |> Stream.take(0x08)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

    parse_data_descriptors(stream, data_descriptors_offset, data_descriptors_count)
  end

  def parse_data_descriptors(stream, data_descriptors_offset, data_descriptors_count) do
    stream
      |> Stream.drop(data_descriptors_offset)
      |> Stream.take(0x08 * data_descriptors_count)
      |> Stream.chunk_every(0x08)
      |> Stream.map(fn data ->
        <<
          tdo::little-integer-size(32),
          pdo::little-integer-size(32)
        >> = data |> :erlang.list_to_binary()
        
        desc =
          stream
          |> Stream.drop(tdo)
          |> Stream.take(0x0C)
          |> Stream.chunk_every(0x0C)
          |> Stream.map(fn d -> parse_descriptor(stream, d) end)
          |> Enum.to_list()
        pal =
          if pdo != 0 do
            parse_palette_data(stream, pdo)
          else
            []
          end
        desc ++ [pal]
      end)
      |> Enum.concat
      |> List.flatten

  end 

  def parse_sprite_header(data, stream) do
    <<
      offset::little-integer-size(32),
      unknown1::little-integer-size(8),
      bytes::integer-size(16),
      count::little-integer-size(8)
    >> = data |> :erlang.list_to_binary()

    assemblies =
      stream
      |> Stream.drop(offset)
      |> Stream.take(count * 0x06)
      |> Stream.chunk_every(0x06)
      |> Enum.map(&parse_assembly_data/1)

    width =
      assemblies
      |> Enum.map(&(&1.dest_x + &1.width))
      |> Enum.max()

    height =
      assemblies
      |> Enum.max_by(& &1.dest_y)
      |> (fn x -> x.dest_y + x.height end).()

    [ new_sprite(bytes, count, offset, unknown1, width, height, assemblies) ]
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
    >> = data |> :erlang.list_to_binary()
    # can't figure out how to do this in the above match but it seems possible...?
    <<y::integer-size(6), x::integer-size(10)>> = <<source_coords::size(16)>>

    new_assembly(hShift, vShift <<< 1, x, y <<< 3, width, height >>> 2)
  end

  def parse_descriptor(stream, descriptor_data) do
    # there are actually 8bytes more of unknown data assoc with textures
    <<
      height::little-integer-size(16),
      unknown::little-integer-size(16),
      width::little-integer-size(16),
      format::little-integer-size(16),
      offset::little-integer-size(32)
    >> = descriptor_data |> :erlang.list_to_binary()
  
    case format do
      0x04 -> new_texture(format, offset, unknown, width, height)
      0x05 -> new_texture(format, offset, unknown, width, height)
      0xFFFF -> 
        case parse_control_data(stream, offset) do
          {:palette, palette_data} -> with_palette([], palette_data)
          {:sprite, sprite_data} -> with_sprite([], sprite_data)
          {:unknown, str} -> IO.puts(str)
        end
      _ -> 
        IO.puts("Unknown format #{format}, ignoring...")
        nil
    end
  end

  def parse_control_data(stream, offset) do
    <<
      sprite_header::little-integer-size(32),
      sprite_count::little-integer-size(32)
    >> =
      stream
      |> Stream.drop(offset)
      |> Stream.take(0x08)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

    case sprite_header do
      0x08 ->
        sprite_data =
          stream
          |> Stream.drop(offset + 0x08)
          |> Stream.take(sprite_count * 0x08)
          |> Stream.chunk_every(0x08)
          |> Enum.map(&parse_sprite_header(&1, stream |> Stream.drop(offset)))
          |> Enum.concat
        {:sprite, sprite_data}

      0x00706162 ->
        << colors::little-integer-size(16) >>
          = stream
          |> Stream.drop(offset + 0x08)
          |> Stream.take(0x02)
          |> Enum.to_list()
          |> :erlang.list_to_binary()
        palette_data = new_palette(colors, 0x03, offset + 0x10)
          
        {:palette, palette_data}
      _ -> 
        <<code::integer-size(32)>> = <<sprite_header::little-size(32)>>
        {:unknown, "Unkown controller: #{Integer.to_string(code, 16)}, ignoring" }
    end
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

    new_texture(format, offset, unknown, width, height)
  end

  def parse_palette_data_header(data) do
    <<
      colors::little-integer-size(16),
      mode::little-integer-size(16),
      offset::little-integer-size(32)
    >> = data |> :erlang.list_to_binary()

    new_palette(colors, mode, offset)
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
      |> Enum.drop(assembly.src_y)
      |> Enum.take(assembly.height)
      |> Enum.map(fn row ->
        row
        |> Enum.drop(assembly.src_x)
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
    |> Enum.map(fn sprite ->
      pixel_data = assemble_sprite(sprite, texture_array, texture_width)
      height = sprite.height
      width = sprite.width

      %{
        pixel_data: pixel_data,
        height: height,
        width: width,
        dest_x: max_width - width,
        dest_y: (max_height + 1 - height) # (max_height + 1) * idx + (max_height + 1 - height) |> IO.inspect(label: "dest_y")
        # there is a pattern emerging here around combining tiles
      }
    end)
    |> Enum.reduce([], fn sprite, acc ->
      pad_top = tile_of_zeroes(sprite.dest_y, max_width)
      pad_left = tile_of_zeroes(sprite.dest_x, sprite.height)
      #pad_bottom = tile_of_zeroes(max_width, 1)
      pad_bottom = Stream.repeatedly(fn -> <<15>> end) |> Enum.take(max_width) |> Enum.chunk_every(max_width) #tile_of_zeroes(max_width, 1)

      padded_left = Enum.zip_with([pad_left, sprite.pixel_data], &Enum.concat/1)
      Enum.concat([pad_top, padded_left, pad_bottom])
      |> (fn s -> Enum.concat(acc, s) end).()
    end)
    |> List.flatten()
    |> :erlang.list_to_binary()
  end

  def is_sprite?(info) when is_list(info), do: is_sprite?(List.first(info))
  def is_sprite?(info) when is_map(info), do: Map.has_key?(info, :olde)
  def is_sprite?(_), do: false

  def sheet_dimensions(sprites) do
    {
      sprites |> Enum.map(& &1.width) |> Enum.max(),
      sprites |> Enum.map(& &1.height) |> Enum.max() |> :erlang.+(1) |> :erlang.*(Enum.count(sprites))
    }
  end
    

  def as_png(input_file_name, opts \\ []), do: as_png(input_file_name, Path.basename(input_file_name, ".tpl"), opts)

  @spec as_png(String.t(), String.t(), Keyword.t()) :: {:ok, binary} | {:error, String.t()}
  def as_png(input_file_name, base_output_file_name, opts) do
    output_file_name = base_output_file_name
    stream = File.stream!(input_file_name, [], 1)
    info = parse_tpl(stream)
    texture_data = assemble_texture_array(stream, texture(info), texture_bytes(info)) |> List.flatten
    palette_data = get_palette(stream, palette(info).offset, palette(info).colors)

    {pixel_data, width, height} = 
      if Keyword.has_key?(info, :sprite) do
        cond do
          Keyword.has_key?(opts, :sprite_index) ->
            # output single sprite  
            idx = Keyword.get(opts, :sprite_index)
            sprites = 
              Keyword.get_values(info, :sprite)
              |> Enum.filter(&(&1.unknown == idx))
            # { assemble_sprite_sheet(sprite, texture_data, texture(info).width), sprite.width, sprite.height }
            Tuple.insert_at(sheet_dimensions(sprites), 0, assemble_sprite_sheet(sprites, texture_data, texture(info).width))
          Keyword.has_key?(opts, :texture) ->
            # output just texture
            { texture_data |> :erlang.list_to_binary(), texture(info).width, texture(info).height }
          true ->
            # output spritesheet
            sprites = Keyword.get_values(info, :sprite) #|> Enum.sort_by(& &1.unknown) #Enum.group_by(& &1.unknown) |> Map.to_list |> Enum.sort_by(&(elem(&1, 0))) |> Enum.map(&(elem(&1, 1))) |> List.flatten
            Tuple.insert_at(sheet_dimensions(sprites), 0, assemble_sprite_sheet(Keyword.get_values(info, :sprite), texture_data, texture(info).width)) 
        end
      else 
        # no sprite, just output texture(s)
        { texture_data |> :erlang.list_to_binary(), texture(info).width, texture(info).height }
      end

    make_png(palette_data, pixel_data, width, height, output_file_name <> ".png")
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

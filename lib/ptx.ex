defmodule Ptx do

  @magic_number << 0x50, 0x54, 0x58, 0x40 >>

  def to_binary(list_of_binaries) do
    Enum.reduce(list_of_binaries, fn x, acc -> acc <> x end)
  end

  def parse_ptx(stream) do
  
    <<
      magic_number::bitstring-size(32),
    >> = stream
         |> Stream.take(0x04)
        |> to_binary

    if magic_number != @magic_number do
      {:error, "Does not appear to be a PTX file - magic number did not match"}
    else

        <<
          unknown_short1::little-integer-size(16),
          unknown_short2::little-integer-size(16),
          width::little-integer-size(16),
          height::little-integer-size(16),
          unknown_long::bitstring-size(32),
          colors::little-integer-size(32),
          indexing::little-integer-size(8),
          unknown_short3::little-integer-size(16),
          unknown_char1::little-integer-size(8),
          palette_offset::little-integer-size(32),
          data_offset::little-integer-size(32)
        >> = stream
            |> Stream.drop(0x04)
            |> Stream.take(0x1C)
            |> to_binary

        palette = parse_palette(stream |> Stream.drop(palette_offset), colors)

      
        unknowns = 
          %{
            addr_0x04: unknown_short1,
            addr_0x06: unknown_short2,
            addr_0x0C: unknown_long,
            addr_0x15: unknown_short3,
            addr_0x17: unknown_char1,
          }

        %{
          palette: palette,
          width: width,
          height: height,
          indexing: indexing,
          data_offset: data_offset,
          unknowns: unknowns
        }
      end
  end

  def parse_palette(stream, colors) do
    stream
    |> Stream.take(colors * 0x04)
    |> Stream.chunk_every(0x04)
  end

  def as_png(input_file_name), do: as_png(input_file_name, Path.join(
  [Path.dirname(input_file_name), 
    Path.basename(input_file_name, ".ptx") <> ".png"
  ]))
  def as_png(input_file_name, output_file_name) do
    stream = File.stream!(input_file_name, [], 1)
    info = parse_ptx(stream)
    as_png(stream, info, output_file_name)
  end
  def as_png(stream, info, file_name) do
    pixel_data = 
      stream
      |> Stream.drop(info.data_offset)
      |> nibble(info.indexing)
      |> Stream.take(info.width * info.height)
      |> Enum.to_list
      |> List.flatten
      |> to_binary
    
    case Png.make_png
      |> Png.with_width(info.width)
      |> Png.with_height(info.height)
      |> Png.with_color_type(info.palette |> Enum.to_list())
      |> Png.with_bgra()
      |> Png.execute(pixel_data)
        do
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

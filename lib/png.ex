defmodule Png do
  # this module is 80% courtesy of https://stackoverflow.com/a/8113783
  @behaviour Identification

  @magic_number <<137, 80, 78, 71, 13, 10, 26, 10>>
  @plte_tag <<80, 76, 84, 69>>
  @idat_tag <<73, 68, 65, 84>>
  @trns_tag <<116, 82, 78, 83>>

  @impl Identification
  def is?(file_name) do
    << 
      magic_number::bitstring-size(64)
    >> = File.stream!(file_name, [], 1)
      |> Stream.take(0x08)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

    magic_number == @magic_number
  end
  @impl Identification
  def extension(), do: "png"

  

  def make_png() do
    %{
      width: nil,
      height: nil,
      bit_depth: 8,
      color_type: nil,
      bgra: false
    }
  end

  def with_width(opts, width), do: %{opts | width: width}

  def with_height(opts, height), do: %{opts | height: height}

  def with_bit_depth(opts, bit_depth), do: %{opts | bit_depth: bit_depth}

  def with_bgra(opts), do: %{opts | bgra: true}

  def with_color_type(opts, palette) when is_list(palette),
    do: %{opts | color_type: {3, convert_palette_to_internal_representation(palette)}}

  def with_color_type(opts, color_type), do: %{opts | color_type: color_type}

  def no_filter(width, pixel_data) do
    pixel_data
    |> :binary.bin_to_list
    |> Enum.map_every(width, fn x -> <<0, x>> end)
    |> :erlang.list_to_binary
  end

  def execute(opts, pixel_data) do
    execute_options(opts.width, opts.height, opts.bit_depth, opts.color_type, pixel_data, opts.bgra)
  end

  def execute_options(width, height, bit_depth, {3, palette}, pixel_data, bgra)
      when not is_nil(width) and not is_nil(height) and not is_nil(bit_depth) do
    {:ok,
     @magic_number <>
       header_chunk(width, height, bit_depth, 3) <>
       plte_chunk(palette, bgra) <>
       data_chunk(pixel_data, &no_filter(width, &1)) <>
       end_chunk()}
  end

  def execute_options(width, height, bit_depth, color_type, pixel_data, _bgra)
      when not is_nil(width) and not is_nil(height) and not is_nil(bit_depth) and
             not is_nil(color_type) do
    {:ok,
     @magic_number <>
       header_chunk(width, height, bit_depth, color_type) <>
       data_chunk(pixel_data, &no_filter(width, &1)) <>
       end_chunk()}
  end

  def execute_options(_width, _height, _bit_depth, _color_type, _pixel_data, _bgra) do
    {:error, "Options invalid"}
  end


  def header_chunk(width, height, bit_depth, color_type) do
    ihdr = <<73, 72, 68, 82>>
    compression_method = <<0>>
    filter_method = <<0>>
    interlace_method = <<0>>

    <<0, 0, 0, 13>> <>
      ((ihdr <>
          <<width::size(32)>> <>
          <<height::size(32)>> <>
          <<bit_depth::size(8)>> <>
          <<color_type::size(8)>> <>
          compression_method <>
          filter_method <>
          interlace_method)
       |> crc_of_chunk())
  end

  def data_chunk(pixel_data, filter_method) do
    z = :zlib.open()
    #:zlib.deflateInit(z)
    :zlib.deflateInit(z, :default, :deflated, 14, 8, :default)
    compressed = :zlib.deflate(z, filter_method.(pixel_data), :finish)
    #:zlib.deflateEnd(z)
    :zlib.close(z)
    #compressed = :zlib.zip(pixel_data)
    data = compressed |> List.flatten() |> :erlang.list_to_binary

    <<byte_size(data)::size(32)>> <>
      ((@idat_tag <>
        data)
       |> crc_of_chunk)
  end

  defp convert_palette_to_internal_representation(palette) when is_list(palette) do
    color_bitstring = fn
      row when is_map_key(row, :alpha) -> <<row.red, row.green, row.blue, row.alpha>>
      row when is_map_key(row, :a) -> <<row.r, row.g, row.b, row.a>>
      row when is_map_key(row, :red) -> <<row.red, row.green, row.blue>>
      row -> <<row.r, row.g, row.b>>
    end

    case List.first(palette) do
      first when is_bitstring(first) ->
        palette

      first when is_list(first) ->
        Enum.map(palette, &Enum.reduce(&1, fn x, acc -> acc <> x end))

      first when is_map(first) ->
        Enum.map(palette, &Enum.reduce(&1, fn x, acc -> acc <> color_bitstring.(x) end))

      _ ->
        palette
    end
  end

  defp has_four_channels(palette) do
    case List.first(palette) do
      first when is_bitstring(first) ->
        try do
          <<_r, _g, _b, _a>> = List.first(palette)
          true
        rescue
          _ -> false
        end

      _ ->
        false
    end
  end

  def plte_chunk(palette, bgra \\ false) do
    {color_palette, trns} =
      if has_four_channels(palette) do
        {palette |> Enum.reduce(<<>>, fn <<r, g, b, _a>>, acc -> if bgra do acc <> <<b, g, r>> else  acc <> <<r, g, b>> end end),
          palette |> Enum.reduce(<<>>, fn <<_r, _g, _b, a>>, acc -> acc <> <<a>> end) |> trns_chunk}
      else
        {List.flatten(palette) |> Enum.reduce(<<>>, fn x, acc -> acc <> x end), <<>>}
      end

    <<byte_size(color_palette)::size(32)>> <>
      ((@plte_tag <>
          color_palette)
       |> crc_of_chunk) <>
      trns
  end

  def trns_chunk(alpha_values) do
    <<byte_size(alpha_values)::size(32)>> <>
      ((@trns_tag <>
          alpha_values)
       |> crc_of_chunk)
  end

  def end_chunk() do
    <<0, 0, 0, 0>> <>
      (<<73, 69, 78, 68>>
       |> crc_of_chunk())
  end

  def crc_of_chunk(chunk) do
    crc = <<:erlang.crc32(chunk)::32>> # Crc.crc32(chunk)::32>>
    chunk <> crc
  end
end

defmodule Gmp do
  
  @behaviour Extractor

  def parse_gmp(stream) do
    <<
      filecount::little-integer-size(32),
      metadata_offset::little-integer-size(32),
      unknown1::little-integer-size(32),
      unknown2::little-integer-size(32)
    >> = stream
      |> Enum.take(0x10)
      |> :erlang.list_to_binary()

    %{
      filecount: filecount,
      metadata_offset: metadata_offset,
      unknown1: unknown1,
      unknown2: unknown2
    }
  end

  def parse_metadata(filecount, stream) do
    stream
    |> Stream.take(filecount * 0x20)
    |> Stream.chunk_every(0x20)
    |> Stream.with_index()
    |> Enum.map(fn {chunk, index} ->
      <<
        raw_filename::binary-size(0x14),
        runlength::little-integer-size(32),
        offset::little-integer-size(32),
        unknown::little-integer-size(32)
      >> = chunk
        |> :erlang.list_to_binary()

      filename = String.trim_trailing(raw_filename, <<0>>)

      # unknown = roles or perhaps layers
      # ex from bm01a.gmp:
      # 0x00 background mesh
      # 0x01 shadow map
      # 0x04 objects
      # 0x06 foreground mesh

      %{
        filename: if filename == "" do Integer.to_string(index) else filename end,
        offset: offset,
        runlength: runlength,
        unknown: unknown 
      }
    end)
  end

  @impl Extractor
  def extract(data) do
    stream = data |> :erlang.binary_to_list()
    gmp = parse_gmp(stream)

    parse_metadata(gmp.filecount, stream |> Stream.drop(gmp.metadata_offset))
    |> Enum.map(fn %{filename: filename, offset: offset, runlength: runlength} ->
      stream
      |> Stream.drop(offset)
      |> Enum.take(runlength)
      |> :erlang.list_to_binary()
      |> (fn filedata -> {filename |> String.to_atom(), filedata} end).()
    end)
    |> Keyword.new()
  end
  
end

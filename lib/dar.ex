defmodule Dar do

  def parse_dar(stream) do
    header = parse_header(stream)
    file_names = parse_file_names(stream, header.file_names_offset, header.file_data_offset)
    file_data = parse_file_data(stream |> Stream.drop(header.file_data_offset), header.file_count)
    files = Stream.zip_with([file_names, file_data], fn [name, data] ->
      Map.put(data, :file_name, name)
    end)
    %{
      header: header,
      files: files
    }
  end

  def parse_header(stream) do
    << 
      file_count::little-integer-size(32),
      _file_data_offset::little-integer-size(32),
      file_names_offset::little-integer-size(32),
      file_data_offset::little-integer-size(32)
    >> = stream
         |> Stream.take(0x10)
         |> Enum.to_list
         |> :erlang.list_to_binary()

    %{
      file_count: file_count,
      file_names_offset: file_names_offset,
      file_data_offset: file_data_offset
    }
  end

  def parse_file_names(stream, file_names_offset, file_data_offset) do
    stream
    |> Stream.drop(file_names_offset)
    |> Stream.take(file_data_offset - file_names_offset)
    |> Stream.chunk_while(<<>>,
      fn
        <<0>>, acc -> {:cont, acc, <<>>}
        char, acc -> {:cont, acc <> char}
      end,
      fn acc -> {:cont, acc} end)
  end

  def parse_file_data(stream, file_count) do
    stream
    |> Stream.take(file_count * 0x10)
    |> Stream.chunk_every(0x10)
    |> Stream.map(&parse_file_data_header/1)
  end

  def parse_file_data_header(data) do
    <<
      _file_name_offset::little-integer-size(32),
      deflated_size::little-integer-size(32),
      inflated_size::little-integer-size(32),
      offset::little-integer-size(32)
    >> = data 
         |> Enum.to_list
         |> :erlang.list_to_binary

    %{
      inflated_size: inflated_size,
      deflated_size: deflated_size,
      offset: offset
    }
  end

  def file_run_length(file_data) do
    if compressed?(file_data) do
      file_data.deflated_size
    else
      file_data.inflated_size
    end
  end

  def compressed?(file_data), do: file_data.deflated_size != 0

  def extract_files(file_name), do: extract_files(file_name, "#{file_name}_files")
  def extract_files(file_name, output_dir) do
    file_stream = File.stream!(file_name, [], 1)
    File.mkdir_p!(output_dir)
    info = parse_dar(file_stream)
    Stream.each(info.files, fn file ->
      file_name = Path.basename(file.file_name)
      dir = Path.join([output_dir, Path.dirname(file.file_name)])
      File.mkdir_p!(dir)
      output_name = Path.join([dir, file_name])
      if compressed?(file) do
        z = :zlib.open()
        :zlib.inflateInit(z)
        file_stream 
          |> Stream.drop(file.offset)
          |> Stream.take(file.deflated_size)
          |> Stream.into(File.stream!(output_name), fn data -> :zlib.inflate(z, data) end)
          |> Stream.run()
        :zlib.close(z)
      else
        file_stream 
          |> Stream.drop(file.offset)
          |> Stream.take(file.inflated_size)
          |> Stream.into(File.stream!(output_name))
          |> Stream.run()
      end
    end)
    |> Stream.run()


  end
end

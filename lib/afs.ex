defmodule Afs do

  @magic_number << 0x41, 0x46, 0x53, 0x00 >>

  def parse_afs(stream) do
    << 
      magic_number::bitstring-size(32),
      file_count::little-integer-size(32) 
    >> = stream
      |> Stream.take(0x08)
      |> Enum.to_list |> :erlang.list_to_binary()

    IO.inspect(file_count)
    if magic_number != @magic_number do
      {:error, "Does not appear to be AFS file"}
    else
      {:ok, parse_files(stream, file_count)}
    end
  end

  def parse_files(stream, file_count) do
    <<
      file_names_offset::little-integer-size(32),
      _file_names_run_length::little-integer-size(32)
    >> = stream
      |> Stream.drop(0x08 + file_count * 0x08)
      |> Stream.take(0x08)
      |> Enum.to_list |> :erlang.list_to_binary()
    IO.inspect(file_names_offset)

    file_data = stream
                |> Stream.drop(0x08)
                |> Stream.take(0x08 * file_count)
                #|> Stream.take(0x08 * 0x01)
                |> Stream.chunk_every(0x08)
                |> Stream.map(&parse_file_data/1)

    file_names = stream
                 |> Stream.drop(file_names_offset)
                 |> Stream.take(0x30 * file_count)
                 #|> Stream.take(0x30 * 0x01)
                 |> Stream.chunk_every(0x30)
                 |> Stream.map(&parse_file_name/1)

    Stream.zip_with([file_data, file_names], fn [d, n] ->
      n
      |> Map.put(:data_offset, d.data_offset)
      |> Map.put(:data_run_length, d.data_run_length)
    end)
  end

  def parse_file_data(data) do
    <<
      data_offset::little-integer-size(32),
      data_run_length::little-integer-size(32)
    >> = data |> Enum.to_list |> :erlang.list_to_binary()

    %{
      data_offset: data_offset,
      data_run_length: data_run_length
    }
  end

  def parse_file_name(data) do
    <<
      file_name::bitstring-size(256),
      unknown1::little-integer-size(32),
      unknown2::little-integer-size(32),
      unknown3::little-integer-size(32),
      unknown4::little-integer-size(32)
    >> = data |> Enum.to_list |> :erlang.list_to_binary()

    %{
      file_name: file_name |> String.trim_trailing(<<0>>),
      unknown1: unknown1,
      unknown2: unknown2,
      unknown3: unknown3,
      unknown4: unknown4
    }
  end

  def extract_files(file_name), do: extract_files(file_name, "#{file_name}_files")
  def extract_files(file_name, output_dir) do
    file_stream = File.stream!(file_name, [], 1)
    File.mkdir_p!(output_dir)
    case parse_afs(file_stream) do
      {:ok, files} -> 
        Stream.each(files, fn file ->
          hex_addr = Integer.to_string(file.data_offset, 16) |> String.pad_leading(8, "0")
          output_name = "0x#{hex_addr}_#{file.file_name}"
          file_stream 
            |> Stream.drop(file.data_offset)
            |> Stream.take(file.data_run_length)
            |> Stream.into(File.stream!(Path.join([output_dir, output_name])))
            |> Stream.run()
        end)
        |> Stream.run()


      {:error, err } -> 
          IO.puts(err)
          
    end


  end

end

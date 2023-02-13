defmodule Fct do
  @behaviour Identification
  @magic_number << 0x46, 0x43, 0x54, 0x00 >>

  @impl Identification
  def is?(file_name) do
    << 
      magic_number::bitstring-size(32)
    >> = File.stream!(file_name, [], 1)
      |> Stream.take(0x04)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

    magic_number == @magic_number
  end
  def info(file_name), do: parse_fct(File.stream!(file_name, [], 1))

  def parse_fct(stream) do
    << 
      magic_number::bitstring-size(32),
      file_count::little-integer-size(32),
      file_data_offset::little-integer-size(32)
    >> = stream
      |> Stream.take(0x0C)
      |> Enum.to_list
      |> :erlang.list_to_binary

    if magic_number != @magic_number do
      {:error, "Does not appear to be FCT file - wrong magic number"}
    else
      {:ok, parse_files(stream |> Stream.drop(file_data_offset), file_count) |> Enum.to_list}
    end
  end

  def parse_files(stream, file_count) do
    stream
    |> Stream.take(file_count * 0x08)
    |> Stream.chunk_every(0x08)
    |> Stream.map(&parse_file_header/1)
  end

  def parse_file_header(data) do
    << 
      file_offset::little-integer-size(32),
      file_size::little-integer-size(32)
    >> = data |> :erlang.list_to_binary

    %{ 
      file_offset: file_offset,
      file_size: file_size
    }
  end

  def extract_files(file_name) do
    dirname = Path.dirname(file_name)
    basename = Path.basename(file_name, ".fct")
    extract_files(file_name, Path.join([dirname, basename]))
  end
  def extract_files(file_name, output_directory) do
    stream = File.stream!(file_name, [], 1)
    
    case parse_fct(stream) do
      {:ok, info} -> 
        File.mkdir_p!(output_directory)
        Enum.each(info, fn file ->
          hex_addr = Integer.to_string(file.file_offset, 16) |> String.pad_leading(8, "0")
          output_file_name = Path.join([output_directory, "0x#{hex_addr}"])
          Stream.drop(stream, file.file_offset)
          |> Stream.take(file.file_size)
          |> Stream.into(File.stream!(output_file_name))
          |> Stream.run()
        end)
      other -> other
    end
  end
end

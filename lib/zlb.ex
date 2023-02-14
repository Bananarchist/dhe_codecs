defmodule Zlb do
  @behaviour Identification
  @behaviour Extractor
  @behaviour Archiver

  @magic_number <<0x5A, 0x4C, 0x42, 0x00>>

  @impl Identification
  def is?(input) when is_binary(input) do
    <<
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input
    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "zlb"

  @doc """
  Accepts a binary/string as input. If a file exists with the input's name it will be opened and the binary data extracted. If not,
  the input will be itself treated as the binary data to test.
  """
  @impl Extractor
  def extract(input) do
    binary_data = 
      if File.exists?(input) do
        File.stream!(input, [], 1) |> Enum.to_list()
      else
        input
      end
        
    if is?(binary_data) do
      {:ok, :erlang.binary_part(binary_data, {byte_size(binary_data), -(byte_size(binary_data) - 8)})
        |> :zlib.uncompress()
        }
    else
      {:error, "Does not appear to be ZLB type file" }
    end
  end

  @doc """
  This puts files into the Sting "zlb" format
  Passing multiple files will combine them, but this format contains no directory so it should only be used when such result is acceptable.
  For the above reason, this method will not handle directories.
  """
  @impl Archiver
  def archive(file_names) when is_list(file_names) do
    if Enum.all?(file_names, fn f -> File.exists?(f) and not File.dir?(f) end) do
      file_names
      |> Enum.map(&File.stream!/1)
      |> Enum.join()
      |> archive()
    else
      file_no_existe = Enum.find(file_names, fn f -> not File.exists?(f) end)
      {:error, if(file_no_existe == nil, do: "Cannot handle directories", else: "#{file_no_existe} doesn't exist")}

    end
  end

  @impl Archiver
  def archive(file_data) when is_binary(file_data) do
    {:ok, @magic_number <> <<byte_size(file_data)::little-integer-size(32)>> <> :zlib.compress(file_data) }
  end
end

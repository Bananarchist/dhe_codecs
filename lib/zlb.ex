defmodule Zlb do
  @behaviour Identification
  @behaviour Extractor

  @magic_number <<0x5A, 0x4C, 0x42, 0x00>>

  @impl Identification
  def is?(file_name) do
    <<
      magic_number::bitstring-size(32)
    >> =
      File.stream!(file_name, [], 1)
      |> Stream.take(0x04)
      |> Enum.to_list()
      |> :erlang.list_to_binary()

    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "zlb"

  @impl Extractor
  def extract(file_name) do
    if is?(file_name) do
      File.stream!(file_name, [], 1)
      |> Enum.drop(8)
      |> :zlib.uncompress()
      |> (fn data ->
            new_file_name = "#{file_name}_uncompressed"

            case File.write(new_file_name, data) do
              :ok -> {:ok, new_file_name}
              {:error, err} -> {:error, "Could not write to #{new_file_name}: #{to_string(err)}"}
            end
          end).()
    end
  end
end

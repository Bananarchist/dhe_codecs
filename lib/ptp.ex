defmodule Ptp do
  @behaviour Identification
  @behaviour Extractor

  @magic_number <<0x50, 0x54, 0x50, 0x00>>

  @impl Identification
  def is?(input) do
    <<
      magic_number::bitstring-size(32),
      _rest::binary
    >> = input

    magic_number == @magic_number
  end

  @impl Identification
  def extension(), do: "ptp"

  def parse_ptp(stream) do
    if not is?(Stream.take(stream, 0x04) |> Enum.to_list() |> :erlang.list_to_binary()) do
      {:error, "Does not appear to be a PTP file - magic number did not match"}
    else
      <<total_files::little-integer-size(32)>> =
        Stream.drop(stream, 0x04) |> Enum.take(0x04) |> :erlang.list_to_binary()

      Stream.drop(stream, 0x10)
      |> Stream.take(0x04 * total_files)
      |> Stream.chunk_every(0x04)
      |> Enum.map(fn bights ->
        <<offset::little-integer-size(32)>> = :erlang.list_to_binary(bights)
        offset
      end)
    end
  end

  @impl Extractor
  def extract(data) do
    stream = :erlang.binary_to_list(data)

    case parse_ptp(stream) do
      {:error, e} ->
        {:error, e}

      file_offsets ->
        file_offsets
        |> Enum.chunk_every(2, 1)
        |> Enum.map(fn offsets ->
          {start, stop} =
            if Enum.count(offsets) == 1 do
              {List.first(offsets), Enum.count(stream)}
            else
              List.to_tuple(offsets)
            end

          Stream.drop(stream, start)
          |> Stream.take(stop - start)
          |> Enum.to_list()
          |> :erlang.list_to_binary()
        end)
    end
  end
end

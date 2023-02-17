defmodule Tile do
  defstruct data: [],
            width: 0,
            height: 0,
            empty: <<0>>

  def width(%Tile{} = tile), do: tile.width
  def height(%Tile{} = tile), do: tile.height

  def update(%Tile{} = tile, key, mapper) do
    Map.update!(tile, key, mapper)
  end

  def update(%Tile{} = tile, [{key, mapper} | rest]) do
    update(tile, key, mapper) |> update(rest)
  end

  def update(%Tile{} = tile, []), do: tile

  def empty(%Tile{} = tile),
    do: update(tile, data: fn _ -> [] end, width: fn _ -> 0 end, height: fn _ -> 0 end)

  def empty(), do: %Tile{}

  def map(%Tile{} = tile, mapper) do
    Enum.reduce(tile, %Tile{tile | data: []}, fn el, acc ->
      new_row = mapper.(el)
      new_width = Enum.count(new_row)
      update(acc, data: fn d -> [new_row | d] end, width: fn _ -> new_width end)
    end)
    |> update(data: &Enum.reverse/1)
    |> update(data: &List.flatten/1)
  end

  def filler(%Tile{} = tile) do
    Stream.repeatedly(fn -> tile.empty end)
    |> Stream.take(height(tile) * width(tile))
    |> Enum.into(tile)
  end

  def filler(width, height, initial) do
    Stream.repeatedly(fn -> initial end) |> Enum.take(height * width)
  end

  def pad(%Tile{} = tile, left \\ 0, top \\ 0, right \\ 0, bottom \\ 0) do
    original_height = height(tile)
    original_width = width(tile)
    new_width = left + original_width + right
    new_height = top + original_height + bottom
    left_pad = filler(%Tile{width: left, height: original_height})
    right_pad = filler(%Tile{width: right, height: original_height})
    top_pad = filler(%Tile{width: new_width, height: top})
    bottom_pad = filler(%Tile{width: new_width, height: bottom})

    horizontally_padded =
      Enum.zip_with([left_pad, tile, right_pad], &Enum.concat/1)
      |> Enum.into(%Tile{width: new_width, height: original_height})

    Enum.concat([top_pad, horizontally_padded, bottom_pad])
    |> Enum.into(%Tile{tile | data: [], width: new_width, height: new_height})
  end

  def slice(%Tile{} = tile, left \\ 0, top \\ 0, right \\ 0, bottom \\ 0) do
    original_height = height(tile)
    original_width = width(tile)
    new_width = original_width - right - left
    new_height = original_height - bottom - top

    if new_width <= 0 or new_height <= 0 do
      empty(tile)
    else
      map(tile, fn row ->
        Enum.drop(row, left)
        |> Enum.take(new_width)
      end)
      |> Enum.drop(top)
      |> Enum.take(new_height)
      |> Enum.into(%Tile{tile | data: [], width: new_width, height: new_height})
    end
  end
end

defimpl Collectable, for: Tile do
  def into(%Tile{} = tile) do
    collector_fun = fn
      _acc, :halt ->
        :ok

      {t, acc}, :done ->
        {width, height} = {Tile.width(t), Tile.height(t)}

        cond do
          width == 0 and height == 0 ->
            Tile.update(t, width: fn _ -> acc end, height: fn _ -> 1 end)

          true ->
            t
        end

      {t, acc}, {:cont, elem} ->
        {Tile.update(t,
           data: fn d -> Enum.concat(d, if(is_list(elem), do: elem, else: [elem])) end
         ), acc + 1}
    end

    {{tile, 0}, collector_fun}
  end
end

defimpl Enumerable, for: Tile do
  def count(%Tile{} = tile) do
    {:ok, Tile.height(tile)}
  end

  def member?(%Tile{} = _tile, _elem) do
    {:error, __MODULE__}
  end

  def reduce(_tile, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(%Tile{} = tile, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(tile, &1, fun)}

  def reduce(%Tile{} = tile, {:cont, acc}, fun) do
    if Tile.width(tile) == 0 or Tile.height(tile) == 0 do
      {:done, acc}
    else
      row = Enum.take(tile.data, Tile.width(tile))

      Tile.update(tile,
        data: fn d -> Enum.drop(d, Tile.width(tile)) end,
        height: fn h -> h - 1 end
      )
      |> reduce(fun.(row, acc), fun)
    end
  end

  def slice(%Tile{} = tile) do
    if Tile.height(tile) == 0 or Tile.width(tile) == 0 do
      {:ok, 0, fn _, _, _ -> tile end}
    else
      {:ok, Tile.height(tile),
       fn start, amount, step ->
         Tile.update(tile,
           height: fn _ -> Integer.floor_div(amount, step) end,
           data: fn d ->
             d
             |> Enum.chunk_every(Tile.width(tile))
             |> Enum.slice(Range.new(start, amount, step))
             |> Enum.concat()
           end
         )
       end}
    end
  end
end

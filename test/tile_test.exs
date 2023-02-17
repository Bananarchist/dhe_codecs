defmodule TileTest do
  use ExUnit.Case
  use ExUnitProperties

  def new_tile({w, h}) do
    %Tile{
      width: w,
      height: h,
      data: Stream.repeatedly(fn -> <<0>> end) |> Enum.take(w * h)
    }
  end

  property "padding increases width, height, and data length" do
    tile_generator = 
      map({positive_integer(), positive_integer()}, &new_tile/1)
    check all tile <- tile_generator,
              left <- positive_integer(),
              right <- positive_integer(),
              top <- positive_integer(),
              bottom <- positive_integer(),
              new_width = Tile.width(tile) + left + right,
              new_height = Tile.height(tile) + top + bottom,
              padded = Tile.pad(tile, left, top, right, bottom) do
      assert Tile.width(padded) == new_width
      assert Tile.height(padded) == new_height
      assert Enum.count(padded.data) == new_width * new_height
    end
  end

  property "slicing decreases width, height, and data length" do
    tile_generator = 
      map({positive_integer(), positive_integer()}, &new_tile/1)
    check all tile <- tile_generator,
              left <- positive_integer(),
              right <- positive_integer(),
              top <- positive_integer(),
              bottom <- positive_integer(),
              new_width = max(0, Tile.width(tile) - left - right),
              new_height = max(0, Tile.height(tile) - top - bottom),
              padded = Tile.slice(tile, left, top, right, bottom) do
      assert Tile.width(padded) == if new_height != 0, do: new_width, else: 0
      assert Tile.height(padded) == if new_width != 0, do: new_height, else: 0
      assert Enum.count(padded.data) == new_width * new_height
   end
  end
end

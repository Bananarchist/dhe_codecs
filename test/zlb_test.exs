defmodule ZlbTest do
  use ExUnit.Case
  use ExUnitProperties

  property "zlb decompresses its own compressions" do
    check all data <- binary(),
              {:ok, compressed} = Zlb.archive(data),
              {:ok, decompressed} = Zlb.extract(compressed) do
      assert decompressed == data
    end
  end
end

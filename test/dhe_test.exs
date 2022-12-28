defmodule DheTest do
  use ExUnit.Case
  doctest Dhe

  test "greets the world" do
    assert Dhe.hello() == :world
  end
end

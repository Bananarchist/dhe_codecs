defmodule Identification do
  @doc """
  Is given file an instance of module filetype or not?
  """
  @callback is?(String.t) :: boolean 
end

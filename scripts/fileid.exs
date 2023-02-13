tests = [
  Cns,
  Fct,
  Png,
  Pta,
  Ptg,
  Ptp,
  Ptx,
  Spa,
  Vpd,
  Zlb
]

id_file = fn file_name ->
  if not File.dir?(file_name) do
    match = Enum.find(tests, & &1.is?(file_name))
    if match == nil do
      IO.puts("Could not find a match for file #{file_name}")
    else
      ext = match |> to_string |> String.replace("Elixir", "") |> String.downcase
      if not String.contains?(file_name, ext) do
        new_file_name = "#{file_name}#{ext}"
        IO.puts("Renaming #{file_name} to #{new_file_name}")
        File.rename(file_name, new_file_name)
      end
    end
  end
end

System.argv
|> Enum.map(id_file)


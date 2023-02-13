id_file = fn file_name ->
  case Identification.identify(file_name) do
    {:error, _} -> IO.puts("Could not find a match for file #{file_name}")
    {:ok, match} ->
      ext = match.extension()
      if not String.contains?(file_name, ext) do
        new_file_name = "#{file_name}#{ext}"
        IO.puts("Renaming #{file_name} to #{new_file_name}")
        File.rename(file_name, new_file_name)
      else
        IO.puts("Renaming #{file_name} unnecessary")
      end
    _ -> IO.puts("Unknown error achieved with #{file_name}")
  end
end

System.argv
|> Enum.map(id_file)


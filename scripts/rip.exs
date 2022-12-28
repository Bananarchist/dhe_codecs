# This file needs access to the following files from the JP SE edition of Riviera PSP
# - SYSDIR/BOOT.BIN 
# - USRDIR/rvdata.bin
# Will rip to a directory structure resembling that of the USRDIR on the US edition of Riviera PSP

file_table = File.stream!("BOOT.BIN", [], 1)
        |> Stream.drop(0x6B0F40)
        |> Stream.take(0x4FC0)
        |> Enum.chunk_every(0x20)
        |> Enum.map(fn entry ->
          <<
            offset :: little-integer-size(32),
            runlength :: little-integer-size(32),
            fname :: binary 
          >> = Enum.reduce(entry, fn x, acc -> acc <> x end)
          %{ 
            :offset => offset,
            :runlength => runlength,
            :filename => (fname |> to_charlist |> Enum.filter(fn x -> x != 0 end))
          }
        end
        )

new_files =
  file_table
  |> Enum.map(fn x ->
    path = ("../output/" <> (to_string x.filename))
    File.mkdir_p!(Path.dirname(path))
    case File.stream!("rvdata.bin", [], 1)
        |> Stream.drop(x.offset)
        |> Stream.take(x.runlength)
        |> Stream.into(File.stream!(path))
        |> Stream.run()
      do
        :ok -> ("Written to " <> path)
        _ -> x
      end
    end
  )

  


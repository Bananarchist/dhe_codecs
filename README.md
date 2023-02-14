
# dhe_codecs


Utilities for decoding the custom file formats used in Sting games, particularly those from the DHE series.

## Purpose
We seek to provide access to the beautiful pieces of multimedia contained in Sting games, some of which may be used for creating walkthroughs, battle guides, bestiaries, etc. This project is organized and run by members of the [Lacrima Castle](https://www.lacrimcastle.net) fansite but, as some of these file formats are not exclusive to Sting! games, for example the GMO and TPL file formats, all contributions are welcome and we hope others can benefit from this as much as Sting fans have.

Files this repo seeks to process:
- AFS
- ARK
- CNS
- DAR
- EXT
- FCT
- FPD
- GMP
- GMO [1]
- IGP
- LIM
- PTA
- PTG
- PTP
- PTX
- SPA
- TPL

[1] This file format has a number of proprietary sources out there due to it being used in Final Fantasy: Dissidia. Finding a decent spec is difficult, however, and the tools are not easily extensible. There are already GMO files that these tools fail on in Sting games, though it's indeterminate if that's an issue in the tool or if it's Sting extending the format for their purposes as they did with the TPL file format. Hence why tools are still needed for the GMO file format.

## Code
There are some classes remaining in Python but it is being actively ported to Elixir for its ergonomics in dealing with binary data, and because Python has betrayed us at least twice since the 2->3 upgrade. Forks in other languages are absolutely encouraged, as they increase the number of tools that can be built. The idea is to create modules for each format so applications can import the modules as necessary, but to also provide a basic interface to conveniently extract/decode files. The fact that many of these formats are not exclusive to Sting! games is part of the reasoning behind this modular structure.


## Opportunities for contributing
Documentation and code is always necessary!

Some feature ideas: 
- Encoding file formats. Take a image.png, for example, and produce a TPL file. Could be used to make custom games using the Sting game engines.
- GUI. Could be used to preview, extract individual sprites, files and textures, probably the best way to go about making it possible to encode the file formats. [Scenic](https://github.com/ScenicFramework/scenic) may be a good library for this.

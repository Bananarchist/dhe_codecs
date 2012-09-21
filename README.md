dhe_codecs
==========

Utilities for decoding the custom file formats used in Sting! games, particularly those from the DHE series.

The purpose of this project is to, first and formost, provide access to the beautiful pieces of multimedia contained in Sting! games, some of which are to be used for creating walkthroughs, battle guides, bestiaries, etc. This project is essentially organized and run by the Lacrima Castle fansite but, as some of these file formats are not exclusive to Sting! games, for example the GMO and TPL file formats, all input is welcome and we hope others can benefit from this as much as Sting! fans will.

The project is currently being written in python, but branches in other languages are more than welcome. The idea is to create python classes for each format so applications could import the classes as necessary, but also allow each class to be run as a standalone program as well. The fact that many of these formats are not exclusive to Sting! games is part of the reasoning behind this modular structure.

Files that need documentation and programming:
- AFS
- ARK
- CNS
- DAR
- EXT
- FCT
- FPD
- GMP
- GMO *
- IGP
- LIM
- PTA
- PTG
- PTP
- PTX
- SPA
- TPL

* This file format has a number of proprietary sources out there due to it being used in Final Fantasy: Dissidia. Finding a decent spec is difficult, however, and the tools are not easily extensible. There are already GMO files that these tools fail on in Sting! games, though it's indeterminate if that's an issue in the tool or if it's Sting! extending the format for their purposes as they did with the TPL file format. Hence why tools are still needed for the GMO file format.


Some branch ideas: 
- Encoding file formats. Take a PNG for example and parse it into a TPL file. Could be used to make custom games using the Sting! game engines.
- GUI. Could be used to preview, extract individual sprites, files and textures, probably the best way to go about making it possible to encode the file formats.
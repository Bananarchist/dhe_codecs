# To do
A list of things that need to be done; consider opening a pull request with one of these fixes/features!

## General
- Storage/production is implemented for few if any of the file formats, eg, archiving files into an AFS
- Extraction for some of the containers is slow; in some cases it may just be better to load them into memory, perhaps deciding based on `File.stat`
  - This also could be a matter of read size, but this too will require some cleverness
- There are recurring patterns around image tiles that can be abstracted
  - At the very least, basic helpers like padding with `<<0>>` on sides can be turned into general utility functions

## Lim.ex
- Does not handle multiple palettes

## Tpl.ex
- 4-bit images are broken
- Sprite assembly is not implemented

## Afs.ex
- Extraction is slow af

## Ptx.ex
- Works about as well as Tpl.ex, _if_ it works that well


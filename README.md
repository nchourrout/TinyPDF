# TinyPDF

Batch PDF shrinker with preview for MacOS

This bash script uses ghostscript to compress PDF files. It can process an individual file or work recursively through a directory.
It can prompt you if you wish to keep the original files or if you're happy with the new ones (using Quick Look).

## Getting started

Requires ghostscript and coreutils: `brew install coreutils ghostcript`

```bash
git clone https://github.com/nchourrout/tinypdf.git && cd tinypdf
```

To compress recursively all files in a directory and preview the compressed files individually.
```bash
./tinypdf.sh -d <DirectoryWithPDFs> -i
```

## Usage

```
Usage: tinypdf.sh (-d DIRECTORY | -f FILE) [-q QUALITY] [-i] [-h]
    -d DIRECTORY base directory
    -f FILE      filename
    -q QUALITY   dpi resolution
    -i           interactive mode (preview compressed files)
    -h           help
```

## Acknowledgments

The compression part is based on [Alfred Klomp's ShrinkPDF](http://www.alfredklomp.com/programming/shrinkpdf/)

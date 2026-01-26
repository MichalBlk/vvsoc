#!/usr/bin/env python3

import sys
import os

def main():
    if len(sys.argv) == 2:
        inpath = sys.argv[1]
        width = 4
        outpath = os.path.splitext(inpath)[0] + ".mem"
    elif len(sys.argv) == 3:
        inpath = sys.argv[1]
        width = int(sys.argv[2])
        outpath = os.path.splitext(inpath)[0] + ".mem"
    elif len(sys.argv) == 4:
        inpath = sys.argv[1]
        width = int(sys.argv[2])
        outpath = sys.argv[3]
    else:
        print(f"Usage: {sys.argv[0]} file [width] [output_file]", file=sys.stderr)
        sys.exit(1)

    with open(inpath, "rb") as infile, open(outpath, "w") as outfile:
        while True:
            chunk = infile.read(width)
            if not chunk:
                break
            value = int.from_bytes(chunk, byteorder="little")
            hexstr = f"{value:0{width * 2}x}"
            outfile.write(hexstr + "\n")

if __name__ == "__main__":
    main()

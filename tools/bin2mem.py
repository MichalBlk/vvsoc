#!/usr/bin/env python3

import sys
import os

def main():
    if len(sys.argv) == 2:
        width = 4
        inpath = sys.argv[1]
    elif len(sys.argv) == 3:
        width = int(sys.argv[1])
        inpath = sys.argv[2]
    else:
        print(f"Usage: {sys.argv[0]} [width] file", file=sys.stderr)
        sys.exit(1)

    outpath = os.path.splitext(inpath)[0] + ".mem"

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

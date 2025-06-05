#! /bin/bash

in=$(basename -- "$2")
out="${in%.*}.mif"

od -An -vtx$1 -w$1 $2 | cut -c2- > $out

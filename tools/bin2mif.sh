#! /bin/bash

in=$(basename -- "$1")
out="${in%.*}.mif"

od -An -vtx4 -w4 $1 | cut -c2- > $out

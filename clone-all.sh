#!/bin/sh
clonefile=/tmp/clonefile
cp "clone-commands.txt" "$clonefile"
chmod +x "$clonefile"

cd ..
"$clonefile"
rm "$clonefile"
cd root-dev
#!/bin/bash
clonefile=/tmp/clonefile
input="repos.txt"

touch $clonefile

while IFS= read -r line
do
    if ! [[ $line =~ ^::.* ]]; then
		line=`echo $line | sed 's/\r//'` 
        line=${line%/*}
		echo "git clone https://github.com/gemstone/${line}.git" >> $clonefile
	fi
done < "$input"

chmod +x "$clonefile"

cd ..
"$clonefile"
rm "$clonefile"
cd root-dev
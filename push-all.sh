#!/bin/sh
find .. -maxdepth 2 -name .git -type d -execdir git push \;
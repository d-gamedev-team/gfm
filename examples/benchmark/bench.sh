#!/bin/sh
dub -b release-nobounds -a x86_64 --combined --compiler ldc2
read -p "Press a key to continue..."
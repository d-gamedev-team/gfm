#!/bin/sh

rdmd -g -debug -unittest -w -vtls -I.. -I../Derelict3/import -I~/d/phobos/ -I~/d/druntime/src/ examples/simplegl.d --force --chatty

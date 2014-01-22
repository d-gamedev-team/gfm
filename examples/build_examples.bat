@echo off
dub build --config=simplehttp
dub build --config=simplegl
dub build --config=simpleshader
dub build --config=vertexspecification


rem Then make sure SDL2 dynamic library is available

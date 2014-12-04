


:lol
xcopy /Y /e ..\gfm\index.d source
xcopy /Y /e ..\gfm\core source
xcopy /Y /e ..\gfm\logger source
xcopy /Y /e ..\gfm\math source
xcopy /Y /e ..\gfm\image source
xcopy /Y /e ..\gfm\net source
xcopy /Y /e ..\gfm\sdl2 source
xcopy /Y /e ..\gfm\opengl source
xcopy /Y /e ..\gfm\assimp source
xcopy /Y /e ..\gfm\freeimage source
xcopy /Y /e ..\gfm\enet source

rdmd bootDoc\generate.d source

rem goto lol

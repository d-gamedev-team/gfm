Ddoc
<p>
$(LINK2 https://github.com/p0nce/gfm, GFM) is a feature-rich library to ease the creation of video games / multimedia applications with the D programming language. Pick what you need.
</p>

<h3>Overview:</h3>

$(UL
    <p>$(LI gfm.core:
        $(UL
            $(LI $(D queue.d): a dead simple queue/fifo/stack/ring-buffer, with a range interface.)
            $(LI $(D memory.d): aligned malloc/free/realloc.)
         )
    )</p>
    <p>$(LI gfm.math:
        $(UL
            $(LI $(D vector.d): small vectors for 2D and 3D.)
            $(LI $(D matrix.d): small matrices for 2D and 3D.)
            $(LI $(D quaternion.d): quaternions.)
            $(LI $(D box.d): half-open intervals (for eg. rectangles, AABB).)
            $(LI $(D simplerng.d): random distributions: a port of SimpleRNG from John D. Cook.)
            $(LI $(D shapes.d): segment, triangle, sphere, ray, plane, frustum.)
            $(LI $(D funcs.d): useful math functions, polynomial solvers, statistics.)
         )
    )</p>
     <p>$(LI gfm.integers:
        $(UL
            $(LI $(D half.d): 16-bit floating point type.)
            $(LI $(D wideint.d): 2^N bits integers (recursive implementation, covers cent/ucent).)
            $(LI $(D fixedpoint.d): fixed-point numbers.)
         )
    )</p>
    <p>$(LI gfm.opengl:
        $(UL
            $(LI OpenGL wrapper based on package derelict-gl3.)
            $(LI makes easier to use the OpenGL API correctly.)
            $(LI including a matrix stack to replace fixed pipeline.)
            $(LI including compilation of a single source for multiple shaders.)
            $(LI practical shader uniforms support: set them at any time, with id caching, and support pruned uniforms.)
            $(LI legacy multi-texture support which is needed for a low-spec game.)
            $(LI built-in OpenGL debug output forwarding.)
         )
    )</p>

    <p>$(LI gfm.sdl2:
        $(UL
            $(LI SDL 2.x wrapper based on package derelict-sdl2.)
            $(LI including SDL_image and SDL_ttf wrappers.)
            $(LI built-in SDL logging forwarding.)
         )
    )</p>

    <p>$(LI gfm.logger:
        $(UL
            $(LI $(D log.d): coloured console logger implementation based on std.logger.)
         )
    )</p>

    <p>$(LI gfm.freeimage:
        $(UL
            $(LI FreeImage wrapper based on package derelict-fi.)
         )
    )</p>

    <p>$(LI gfm.assimp:
        $(UL
            $(LI Assimp wrapper based on package derelict-assimp3.)
         )
    )</p>
)


<h3>Dealing with resources in D.</h3>

Be sure to read these entries on d-idioms:
$(UL
    $(LI $(LINK http://p0nce.github.io/d-idioms/#The-trouble-with-class-destructors))
    $(LI $(LINK http://p0nce.github.io/d-idioms/#GC-proof-resource-class))
)



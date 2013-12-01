# What's this?

GFM is a feature-rich library to ease the creation of video games / multimedia applications with the D programming language. Pick what you need.

Documentation can be found here: http://p0nce.github.com/gfm/


## License

Public Domain (Unlicense).

## Contents


### core/
  * **log.d** logging interface + implementations (HTML file, colored console output...)
  * **queue.d** a dead simple queue/fifo/stack/ring-buffer, with a range interface
  * **lockedqueue.d** synchronized queue for thread communication
  * **memory.d** aligned malloc/free/realloc
  * **alignedbuffer.d** aligned array-like container
  * **text.d** string utilities

### math/
  * **vector.d** small vectors for 2D and 3D
  * **matrix.d** small matrices for 2D and 3D
  * **quaternion.d** quaternions
  * **half.d** 16-bit floating point type
  * **wideint.d:** 2^N bits integers (recursive implementation, covers cent/ucent)
  * **box.d** half-open intervals (for eg. AABB)
  * **fixedpoint.d** fixed-point numbers
  * **fraction.d** rational numbers
  * **statistics.d** statistical functions
  * **solver.d** polynomial solvers up to quadratic
  * **simplerng.d** random distributions: a port of SimpleRNG from John D. Cook
  * **shapes.d** segment, triangle, sphere, ray...
  * **frustum.d** 3D frustum and 3D plane
  * **funcs.d** useful math functions
  * **simplexnoise.d** Simplex noise implementation

### opengl/
  * OpenGL wrapper based on package derelict-gl3
  * makes easier to use the OpenGL API correctly
  * including a matrix stack to replace fixed pipeline
  * including compilation of a single source for multiple shaders
  * practical shader uniforms support: set them at any time, with id caching, and support pruned uniforms
  * legacy multi-texture support which is needed for a low-spec game
  * FBO support with GL_EXT_framebuffer_object fallback
  * built-in OpenGL debug output forwarding

### net/
  * **uri.d** URI parsing (RFC 3986)
  * **httpclient.d** HTTP client (RFC 2616)
  * **cbor.d** CBOR serialization/deserialization (RFC 7049)

### sdl2/
  * SDL 2.0 wrapper based on package derelict-sdl2
  * including SDL_image and SDL_ttf wrappers
  * built-in SDL logging forwarding
  * framerate statistics  

### image/
  * **image.d** generic abstract image and software rendering routines
  * **bitmap.d** planar and tile-based concrete images
  * **cie.d** physical color computations  
  * **hsv.d** RGB <-> HSV conversions

### freeimage/
  * FreeImage wrapper based on package derelict-fi
  * FIBITMAP wrapper  

### assimp/
  * Assimp wrapper based on package derelict-assimp3
  * scene wrapper

### enet/
  * ENet wrapper based on derelict_extras-enet
  * currently useless

*There is always more to come, don't fear to ask for things*

## How to use GFM?

See the examples/ directory, or https://github.com/p0nce/aliasthis as an example of a game.


## Why use GFM?

In the D1 days, I created several multimedia applications:

  * Vibrant: http://www.gamesfrommars.fr/vibrant/
  * Wormhol: http://www.gamesfrommars.fr/wormhol/
  * Extatique: http://www.pouet.net/prod.php?which=53942
  * The Orange Guy: http://www.pouet.net/prod.php?which=52780
  * SeamzGood: http://www.dsource.org/projects/seamzgood

This all came with some insight with how to do OpenGL applications in D.
During this time I became acutely aware that my quick & dirty coding style wouldn't cut it in the long run.
GFM is the clean successor library to the unfortunate code I was using at this time.


## Design goals

  * give more power to the library user providing code that will probably need to be written anyway.
  * each module / sub-package is maximally decoupled (the major pain point right now is the lack of a standard logging facility).
  * logging interface for everything which need to output messages.
  * correctness and functionality are favoured over speed.
  * wrappers are lightweight layers that expose the C libraries objects, turn every error code into an D exception and makes it easier to use the library correctly.
  * as much as possible, GFM emit warnings when something goes wrong, try to recover when it makes sense and log every problem.


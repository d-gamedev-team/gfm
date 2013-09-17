# gfm


gfm is a collection of useful classes for multimedia programming with the D language.


## Why?


gfm is:
  * a common ground to write multimedia D applications, that I would consider sane.
  * boilerplate code you will probably need to write anyway for eg. a game.
  * decoupled. Pick only the part you need!



## Contents


Everything in this repositery is public domain, except for parts marked with a star (*).
See UNLICENSE for more details.


### common/
  * **log.d** HTML logging object
  * **queue.d** queue/fifo/stack/ring-buffer, with range interface
  * **lockedqueue.d** synchronized queue for thread communication
  * **memory.d** aligned malloc/free/realloc
  * **alignedbuffer.d** aligned array-like container
  * **structpool.d** small object arena
  * **text.d** string utilities


### net/
  * **uri.d** URI parsing (RFC 3986)
  * **httpclient.d** HTTP client (RFC 2616)


### math/
  * **vector.d** small vectors for 2D and 3D
  * **matrix.d** small matrices for 2D and 3D
  * **quaternion.d** quaternions
  * **softcent.d:** 128 bits integers (cent/ucent implentation), including division algorithm from Ian Kaplan\*
  * **box.d** half-open intervals (for eg. AABB)
  * **fixedpoint.d** fixed-point numbers
  * **fraction.d** rational numbers
  * **statistics.d** statistical functions
  * **solver.d** polynomial solvers up to quadratic
  * **simplerng.d** random distributions: a port of SimpleRNG from John D. Cook
  * **shapes.d** segment, triangle, sphere, ray...
  * **plane.d** 3D plane
  * **frustum.d** 3D frustum
  * **funcs.d** useful math functions
  * **simplexnoise.d** Simplex noise implementation


### image/
  * **image.d** generic abstract image and software rendering routines
  * **bitmap.d** planar and tile-based concrete images
  * **cie.d** physical color computations


### sdl2/
  * SDL 2.0 wrapper based on Derelict3
  * including SDL_image and SDL_ttf wrappers
  * framerate statistics


### freeimage/
  * FreeImage wrapper based on Derelict3
  * FIBITMAP wrapper


### opengl/
  * OpenGL wrapper based on Derelict3
  * makes easier to use the OpenGL API correctly
  * including a matrix stack to replace fixed pipeline
  * including compilation of a single source for multiple shaders

### assimp/
  * Assimp wrapper based on Derelict3
  * scene wrapper

*There is always more to come, don't fear to ask for things*

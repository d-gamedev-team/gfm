# The Games From Mars library


GFM is a feature-rich library to ease the creation of video games / multimedia applications with the D programming language.


## Design goals

  * give more power to the library user providing code that will probably need to be written anyway.
  * each module / sub-package is maximally decoupled (the major pain point right now is the lack of a standard logging facility).
  * correctness and functionality are favoured over speed.
  * wrappers are lightweight layers that expose the C libraries objects, turn every error code into an D exception and makes it easier to use the library correctly.
  * as much as possible, gfm emit warnings when something goes wrong, try to recover when it makes sense and log every problem.

## License

Public Domain. See UNLICENSE for more details.

## Contents


### core/
  * **log.d** logging interface + implementations (HTML file, colored console output...)
  * **queue.d** a dead simple queue/fifo/stack/ring-buffer, with a range interface
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
  * **wideint.d:** 2^N bits integers (recursive implementation, covers cent/ucent)
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

### opengl/
  * OpenGL wrapper based on Derelict3
  * makes easier to use the OpenGL API correctly
  * including a matrix stack to replace fixed pipeline
  * including compilation of a single source for multiple shaders
  * practical shader uniforms support: set them at any time, with id caching, and support pruned uniforms
  * legacy multi-texture support which is needed for a low-spec game
  * FBO support with GL_EXT_framebuffer_object fallback
  * built-in OpenGL debug output forwarding

### sdl2/
  * SDL 2.0 wrapper based on Derelict3
  * including SDL_image and SDL_ttf wrappers
  * built-in SDL logging forwarding
  * framerate statistics  

### image/
  * **image.d** generic abstract image and software rendering routines
  * **bitmap.d** planar and tile-based concrete images
  * **cie.d** physical color computations  

### freeimage/
  * FreeImage wrapper based on Derelict3
  * FIBITMAP wrapper  

### assimp/
  * Assimp wrapper based on Derelict3
  * scene wrapper

*There is always more to come, don't fear to ask for things*

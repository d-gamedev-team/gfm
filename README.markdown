# gfm


gfm is a collection of useful classes for multimedia programming with the D language.


## Why?


While building multiples applications with the D programming language, I've come to several conclusions:
  * without a sane common ground, maintenance of multiples such programs is painful
  * restrictive abstractions makes sharing a common ground difficult
  * yet, copy-pasting is not a solution if the project isn't throw-away
  * the power of C libraries is there, but its availability is increased with boilerplate D wrappers
  * in some case like OpenGL, the D wrapper is simply mandatory to deal with portability issues

gfm is:
  * boilerplate code you will probably need to write anyway for eg. a game
  * wrappers that are leaky abstractions but try not to restrict you
  * stuff you will be glad to have when you need to

## Contents


Everything in this repositery is "public domain", except for parts marked with a star (*).
See UNLICENSE for more details.


### common/
  * **log.d** HTML logging object
  * **queue.d** queue/fifo/stack/ring-buffer, with range interface
  * **lockedqueue.d** synchronized queue for thread communication
  * **memory.d** aligned malloc/free/realloc
  * **alignedbuffer.d** aligned array-like container
  * **structpool.d** small object area


### math/
  * **vector.d** small vectors for 2D and 3D
  * **matrix.d** small matrices for 2D and 3D
  * **quaternion.d** quaternions
  * **half.d** half floats
  * **softcent.d:** 128 bits integers (cent/ucent implentation), including division algorithm from Ian Kaplan\*
  * **box.d** half-open intervals (for eg. AABB)
  * **fixedpoint.d** fixed-point numbers
  * **fraction.d** rational numbers
  * **statistics.d** statistical functions
  * **solver.d** polynomial solvers up to quadratic
  * **simplerng.d** random distributions: a port of SimpleRNG from John D. Cook\*
  * **easing.d** a port of easing functions from Robert Penner\*
  * **shapes.d** segment, triangle, sphere, ray...
  * **plane.d** 3D plane
  * **frustum.d** 3D frustum
  * **funcs.d** useful math functions


### image/
  * generic image and plane abstraction
  * physical color computations


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

*More to come*

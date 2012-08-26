gfm
===

gfm is a collection of useful classes for multimedia programming with the D language.


Why?
====

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


Contents
========

Everything in this repositery is "public domain", except for parts marked with a star (*).
See UNLICENSE for more details.


* common/
  * HTML logging object
  * range-based queue/fifo/stack/ring-buffer and locked queue
  * aligned malloc/free/realloc and buffer
  * struct pool


* math/
  * vectors
  * matrices
  * quaternions
  * half floats
  * 128 bits integers (cent/ucent implentation), including division algorithm from Ian Kaplan (*)
  * boxes: half-open intervals
  * fixed-point numbers
  * fractions
  * statistical functions
  * polynomial solvers up to quadratic
  * random distributions: a port of SimpleRNG from John D. Cook (*)
  * a port of easing functions from Robert Penner (*)
  * shapes
  * other useful math functions


* image/
  * generic image and plane abstraction
  * physical color computations


* sdl2/
  * SDL 2.0 wrapper based on Derelict3
  * framerate statistics


* freeimage/
  * freeimage wrapper based on Derelict3
  * FIBITMAP wrapper


* opengl/
  * OpenGL wrapper based on Derelict3
  * makes easier to use the OpenGL API correctly
  * including a matrix stack to replace fixed pipeline
  
more to come

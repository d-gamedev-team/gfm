# What's this?

GFM is a feature-rich library to ease the creation of video games / multimedia applications with the D programming language.

Documentation and overview can be found here: http://d-gamedev-team.github.io/gfm/

[![Build Status](https://travis-ci.org/d-gamedev-team/gfm.png?branch=master)](https://travis-ci.org/d-gamedev-team/gfm)

## License

Public Domain (Unlicense).


## How to use GFM?

Add the sub-package you are interested in in your `dub.json`:
```d
   {
      "dependencies": {
        "gfm:math": "==1.1.8"
      }
   }
```

See the examples/ directory, or https://github.com/p0nce/aliasthis as an example of a game.


## Dependencies

You absolutely don't need to use the whole of GFM. Pick just what you need to minimize the amount of dependencies.

![GFM dependencies](/deps/deps.png)

There is an ongoing work to delete things in GFM that exist elsewhere but better.
See http://code.dlang.org to discover lots of useful libraries for your programs.


## Design goals

  * Give some more power to the library user providing code that will probably need to be written anyway.
  * Each module / sub-package is maximally decoupled.
  * Logging interface for everything that has a logging callback.
  * Correctness and functionality are favoured over speed.
  * Wrappers are transparent layers that expose the C libraries objects, turn every error code into an D exception and makes it easier to use the library correctly. They should not restrict the original library capabilities.

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

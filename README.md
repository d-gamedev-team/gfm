# GFM [![Build Status](https://travis-ci.org/d-gamedev-team/gfm.png?branch=master)](https://travis-ci.org/d-gamedev-team/gfm)

[![Join the chat at https://gitter.im/d-gamedev-team/gfm](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/d-gamedev-team/gfm?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

GFM is a lightweight library to ease the creation of video games / multimedia applications with the D programming language.

Documentation and overview can be found here: http://d-gamedev-team.github.io/gfm/


## License

Public Domain (Unlicense).


## How to use GFM?

Add the sub-package you are interested in in your `dub.json`:
```d
   {
      "dependencies": {
        "gfm:math": "~>3.0"
      }
   }
```

See the examples/ directory, or https://github.com/p0nce/aliasthis as an example of a game.

## Changelog

https://github.com/d-gamedev-team/gfm/wiki/Changelog

## Who uses GFM?
- [aliasthis](https://github.com/p0nce/aliasthis)
- [Despiker](https://github.com/kiith-sa/despiker/blob/master/dub.json)
- [D gamedev intro](https://github.com/kiith-sa/d-gamedev-intro)
- [Dido](https://github.com/p0nce/dido)
- [Pacman](https://github.com/Yoplitein/pacman)
- [petri-dish](https://github.com/Shriken/petri-dish)
- [Vibrant](https://github.com/p0nce/Vibrant)
- [vxlgen](https://github.com/p0nce/vxlgen)

## Why use GFM
  * GFM primarily provides math primitives that are useful for games like vectors/matrices/quaternions in the `gfm:math`package.
  * Wrappers are transparent layers that expose the C libraries objects, turn every error code into an D exception and makes it easier to use the library correctly. They do almost nothing and perhaps you don't need them.
  * GFM has low churn and has been maintained since 2012.

## Dependencies

You absolutely don't need to use the whole of GFM. Pick just what you need to minimize the amount of dependencies.

![GFM dependencies](/deps/deps.png)

There is an ongoing work to delete things in GFM that exist elsewhere but better.
See http://code.dlang.org to discover lots of useful libraries for your programs.


# GFM

<img alt="logo" src="https://cdn.combinatronics.com/p0nce/gfm/master/logo.svg" width="200">


**IMPORTANT 2: GFM has been deprecated in favor of dplug:math. Use version 8 if you want the former content gfm:integer and gfm:math content.**


_Hello,_

_Here is something I wanted to do for a while._
_I'm abandoning `gfm` in favor of `dplug:math` (vectors, matrices, and box), which will be tailored for Dplug needs._
_I know `gfm` has been a reliable and stable library over the years but there should be much better libraries around nowadays. `gfm` has never been super good in usability and purpose; and I just have no need for such a generic library anymore. I hope you understand and go build a better library._
_Overstretching with too many libraries to maintain is not very good for me._
 - p0nce

**IMPORTANT: GFMv8 has been stripped down to gfm:math and gfm:integers only. Use version 7 if you want the former content.**

See the changelog here to upgrade: [https://github.com/d-gamedev-team/gfm/wiki/Changelog](https://github.com/d-gamedev-team/gfm/wiki/Changelog)


## License

Public Domain (Unlicense).


## How to use GFM?

Add the sub-package you are interested in in your `dub.json`:
```d
   {
      "dependencies": {
        "gfm:math": "~>8.0"
      }
   }
```

## Changelog

https://github.com/d-gamedev-team/gfm/wiki/Changelog

## Why use GFM?
  * GFM provides math primitives that are useful for games like vectors/matrices/quaternions in the `gfm:math` package,
  * Also provide arbitrary sized integers, fixed point numbers, and half-float numbers in `gfm:integers`,


## This library is really small now

There used to be a lot more stuff in GFM previously.
See http://code.dlang.org to discover lots of useful libraries for your programs.

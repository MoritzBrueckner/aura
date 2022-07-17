# Changes

This list contains notable changes that may break compatibility with older
versions. Non-breaking changes (e.g. new features) are _not_ listed here.

_The dates below are given as **YYYY.MM.DD**._

- **2022.07.18** ():

  `Aura.dsp.Filter.Channels` was replaced with the new `aura.Types.Channels`
  abstract. `Channels.Both` is now `Channels.All` (Aura currently only supports
  stereo channels) and `Channels.toLeft()`/`Channels.toRight()` have been
  replaced with the more generic `channel.matches()` member function.

- **2022.03.17** ([`0576c1f`](https://github.com/MoritzBrueckner/aura/commit/0576c1f657c5ff11d72f1916ae1b3f81ee0e2be7)):

  `Aura.play()` and `Aura.stream()` were replaced with `Aura.createHandle()`.
  The distinction between both play modes is now handled by the first parameter,
  all other following parameters stay the same:

  ```haxe
  Aura.play(mySound, loop, mixChannelHandle);
  // becomes
  Aura.createHandle(Play, mySound, loop, mixChannelHandle);

  // and

  Aura.stream(mySound, loop, mixChannelHandle);
  // becomes
  Aura.createHandle(Stream, mySound, loop, mixChannelHandle);
  ```

  In addition to that, sounds are no longer auto-played to make it easier to
  pre-initialize their handles. To play them, call `play()` on the returned
  handle.

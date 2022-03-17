# Changes

This list contains notable changes that may break compatibility with older
versions. Non-breaking changes (e.g. new features) are _not_ listed here.

_The dates below are given as **YYYY.MM.DD**._

- **2022.17.03**:

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

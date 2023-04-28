# Changes

This list contains notable changes that may break compatibility with older
versions. Non-breaking changes (e.g. new features) are _not_ listed here.

_The dates below are given as **YYYY.MM.DD**._

- **2023.04.29** ([`8c1da0b`](https://github.com/MoritzBrueckner/aura/commit/8c1da0b039c55f56400f6270ca109b58c4a48526))

  This commit introduced multiple compatibility-breaking changes:

  1. `aura.Handle` is now `aura.Aura.BaseChannelHandle` (a convenience typedef for `aura.channels.BaseChannel.BaseChannelHandle`).

  2. `aura.MixChannelHandle` is now `aura.Aura.MixChannelHandle` (a convenience typedef for `aura.channels.MixChannel.MixChannelHandle`).

  3. `Aura.createHandle()` was replaced with `Aura.createUncompBufferChannel()` as well as `Aura.createCompBufferChannel()`, depending on the first parameter of `createHandle()` that is now obsolete:

    ```haxe
    Aura.createHandle(Play, mySound, loop, mixChannelHandle);
    // becomes
    Aura.createUncompBufferChannel(mySound, loop, mixChannelHandle);

    // and

    Aura.createHandle(Stream, mySound, loop, mixChannelHandle);
    // becomes
    Aura.createCompBufferChannel(mySound, loop, mixChannelHandle);
    ```

    This change is more or less reverting [`0576c1f`](https://github.com/MoritzBrueckner/aura/commit/0576c1f657c5ff11d72f1916ae1b3f81ee0e2be7) and is introduced as part of adding more handle types to distinguish different channel features.
    Now, `Aura.createUncompBufferChannel()` returns `Null<UncompBufferChannelHandle>` (`UncompBufferChannelHandle` is a new type introduced by this commit) and `Aura.createCompBufferChannel()` returns the unspecialized `Null<BaseChannelHandle>`.
    This type-safe compile-time handling of handle types prevents the user from having to cast a returned handle to a specific handle type to get access to the complete functionality of a handle, which would have been required if `Aura.createHandle()` was still used to create handles (thus, [abstraction leaking](https://en.wikipedia.org/wiki/Leaky_abstraction) is minimized).

- **2022.11.21** ([`db8902c`](https://github.com/MoritzBrueckner/aura/commit/db8902c2816cdb7acbe221c97e3f454175df79c5)):

  The way channels are connected to mix channels was changed:

  ```haxe
  final myMixChannel: aura.MixChannelHandle = Aura.createMixChannel();
  final myInputChannnel: aura.Handle = Aura.createHandle(...);

  myMixChannel.removeInputChannel(myInputChannel);
  // becomes
  myInputChannel.setMixChannel(null);

  // and

  myMixChannel.addInputChannel(myInputChannel);
  // becomes
  myInputChannel.setMixChannel(myMixChannel);
  ```

- **2022.09.03** ([`3feb4ee`](https://github.com/MoritzBrueckner/aura/commit/3feb4eec6f5c9e10a7bc305c91c47c2aa1d52e1e)):

  Stereo panning was moved out of the `aura.Handle` class to be completely inside
  the `auda.dsp.panner.StereoPanner` where it actually belongs. This lays the
  groundwork for upcoming changes to the `StereoPanner` and potentially different
  channel formats in the future.

- **2022.07.18** ([`4386c3d`](https://github.com/MoritzBrueckner/aura/commit/4386c3dd6bcfe894016dc0c631c07881cbe7eba6)):

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

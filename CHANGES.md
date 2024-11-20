# Breaking Changes

This list contains notable changes that may break compatibility with previous versions (public API only).
Non-breaking changes (e.g. new features) are _not_ listed here.

_The dates below are given as **YYYY.MM.DD**._

- **2024.11.20** ([]()):

  This commit is part of a bigger rework of asset and audio channel handling.

  `Aura.loadAssets()` was replaced by `aura.Assets.startLoading()` with a slightly different API.
  Instead of specifying which assets to load with an `AuraLoadConfig`, Aura now has its own asset objects that need to be used instead.

  **Before:**
  ```haxe
  var loadConfig: AuraLoadConfig = {
    uncompressed: ["MySoundFile"],
    compressed: ["AnotherSoundFile"],
    hrtf: ["myHRTF_mhr"],
  };

  Aura.loadSounds(loadConfig, () -> {
    trace("Loaded all assets");
  }, () -> {
    trace("Failed to load an asset");
  }, (numLoadedAssets: Int, totalNumAssets: Int) -> {
    trace('Loaded $numLoadedAssets of $totalNumAssets');
  });
  ```

  **Now:**
  ```haxe
  var mySound = aura.Assets.Sound("MySoundFile", Uncompress);
  var anotherSound = aura.Assets.Sound("AnotherSoundFile", KeepCompressed);
  var hrtf = aura.Assets.HRTF("myHRTF_mhr");

  var assetList = [
    mySound,
    anotherSound,
    hrtf,
  ];

  aura.Assets.startLoading(assetList,
    // Callback for successfully loaded assets
    (asset: aura.Assets.Asset, numLoaded: Int, numTotalAssets: Int) -> {
      trace('Loaded $numLoadedAssets of $totalNumAssets: ${asset.name}');

      // Failed assets are not included in totalNumAssets, so the below is safe to use in all cases
      if (numLoaded == totalNumAssets) {
        trace("Loaded all assets");
      }
    },

    // Callback for assets that failed to load
    (asset: aura.Assets.Asset, error: kha.AssetError) -> {
      trace('Failed to load asset ${asset.name}. Reason: $error');
      return AbortLoading;
    }
  );
  ```

  In addition to the above change:
  - `aura.types.HRTF` was renamed to `aura.types.HRTFData`
  - `aura.dsp.panner.HRTFPanner.new()` now expects an `aura.Assets.HRTF` object instead of an `aura.types.HRTFData` object as its second parameter
  - `Aura.getSound()` now returns `Null<aura.Assets.Sound>` instead of `Null<kha.Sound>`
  - `Aura.getHRTF()` now returns `Null<aura.Assets.HRTF>` instead of `Null<aura.types.HRTFData>`
  - `Aura.createUncompBufferChannel()` and `Aura.createCompBufferChannel()` now take an `aura.Assets.Sound` as their first parameter instead of a `kha.Sound`

- **2024.06.25** ([a8a66f6](https://github.com/MoritzBrueckner/aura/commit/a8a66f6d86fc812512dca2e7d5ba07ef0d804cd4)):

  `aura.dsp.panner.Panner.dopplerFactor` was renamed to `aura.dsp.panner.Panner.dopplerStrength`.

- **2024.01.22** ([f7dff6e](https://github.com/MoritzBrueckner/aura/commit/f7dff6ea3840ed7c42c8994a735cc534525d0b63)):

  Previously, if loading an asset with `aura.Aura.loadAssets()` failed, Aura would sometimes continue loading other assets and in other cases stop loading assets of the same type after the first failure, which was rather unintuitive.
  Now, Aura always continues to load other assets even if an asset could not be loaded.

- **2024.01.14** ([`47d4426`](https://github.com/MoritzBrueckner/aura/commit/47d4426ffd93a5efb24eb5dc4c2d2a985e1010f5)):

  The `aura.format.mhr.MHRReader` class is no longer meant to be instantiated, instead it is used statically now:

  ```haxe
  final mhrReader = new aura.format.mhr.MHRReader(mhrBlobBytes);
  final hrtf = mhrReader.read();

  // becomes

  final hrtf = aura.format.mhr.MHRReader.read(mhrBlobBytes);
  ```

- **2023.04.29** ([`8c1da0b`](https://github.com/MoritzBrueckner/aura/commit/8c1da0b039c55f56400f6270ca109b58c4a48526)):

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

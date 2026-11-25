![aura_banner.png](.img/aura_banner_bright.png)

*Aura* is a fast and lightweight 3D audio engine for [Kha](https://kha.tech/) to ease creating realistic sound atmospheres for your games and applications.

# Table of Content
- [Features](#features)
- [Setup](#setup)
- [Usage](#usage)
- [Platform Support](#platform-support)
- [License](#license)

# Features

- Multiple attenuation models for 3D sound
- Mix channels for modifying groups of sounds together
- Doppler effect
- Noise generator channels
- Built-in [DSP](https://en.wikipedia.org/wiki/Digital_signal_processing) filters:
  - High-/band-/lowpass filter
  - Haas effect
  - Per-channel source effects, e.g. to generate variations using Velvet noise ([original paper](http://research.spa.aalto.fi/publications/papers/dafx21-one2many/))
- Extendable DSP system – easily write your own filters
- [[Experimental](https://github.com/MoritzBrueckner/aura/projects/1)] Support for [HRTFs (head-related transfer functions)](https://en.wikipedia.org/wiki/Head-related_transfer_function)

# Setup

1. In your project directory, create a folder called `Subprojects`.
2. Open a command line in that folder and execute the following command (Git must be installed on your machine):

    ```sh
    git clone https://github.com/MoritzBrueckner/aura.git
    ```

3. Add the following line to your project's `khafile.js` (if you're using [Armory 3D](https://armory3d.org/), you can skip this step):

    ```js
    await project.addProject("Subprojects/aura");
    ```

4. *[Optional]* If you're using [Iron](https://github.com/armory3d/iron), but not Armory 3D, please also add the following to your Khafile to be able to use Iron's vector classes with Aura:

    ```js
    project.addDefine("AURA_WITH_IRON");
    ```

# Usage

## Initialize the library (*do not forget this!*)
```haxe
import aura.Aura;

Aura.init();
```

## Load sounds

> [!NOTE]
> The way in which Aura loads sounds and other assets is currently reworked in the [new-asset-loading](https://github.com/MoritzBrueckner/aura/tree/new-asset-loading) branch, so the following will likely change in the future.
> Once this is finished, a list of breaking changes will be listed in [CHANGES.md](https://github.com/MoritzBrueckner/aura/blob/master/CHANGES.md).

Aura can load a sound in two different ways:
- When loading the sound, uncompress it and store the *uncompressed* data in memory.
- When loading the sound, load the *compressed* data into memory. During playback, only the parts of the data that are currently required for playback are temporarily uncompressed. This is called "streaming" in Kha terminology. Whether a sound can be streamed highly depends on the target, please consult the Kha sources if in doubt.

Which way you choose for a given sound usually depends on the sound itself:
fully uncompressing a sound while loading adds a small amount of time to the loading process and results in a larger memory usage, but the sound's playback is more performant. Therefore, short sounds that are played often (e.g., footsteps) are usually loaded and immediately uncompressed whereas sounds such as background music or perhaps voice dialogues are often kept compressed to reduce the memory footprint.

Aura refers to sounds (and other assets) by means of [Kha's asset names](https://github.com/Kode/Kha/wiki/Managing-Your-Assets#assets-names).

```haxe
// Before sounds can be loaded, add the asset names (as used by Kha) of the sounds you want to load
// to an `AuraLoadConfig` instance:
var loadConfig: AuraLoadConfig = {
	// List of sounds to uncompress while loading
	uncompressed: ["MySoundFile", "MyOtherSoundFile"],

	// List of sounds to remain compressed in memory
	compressed: ["AnotherSoundFile"],
};

// Empty lists can be omitted, the following has no uncompressed sounds:
var myOtherLoadConfig: AuraLoadConfig = {
	compressed: ["YetAnotherSoundFile"],
};
```

Instead of referencing sounds by hard-coded names like done in the above example, you can also rely on Kha's asset system that automatically creates static variables for your exported assets:
```haxe
kha.Assets.sounds.MySoundFileName; // Note the "Name" ending.
```
This has two advantages:
- Variables like the above only exist if the sound (or any other asset for which you use this approach) is exported by Khamake, thus causing a compile-time error when the sound does not exist.
-  You can use your IDE's autocompletion for assistance.

Once you listed the sounds you want to load in an `AuraLoadConfig` instance, you can pass this instance to `Aura.loadAssets()` along with a callback function that is automatically called when all assets in the load config are loaded and ready to use:

```haxe
Aura.loadAssets(loadConfig, () -> {
	// Access a loaded sound
	var mySound: kha.Sound = Aura.getSound(kha.Assets.sounds.MySoundFileName);
});
```

> [!CAUTION]
> Note that `Aura.loadAssets()` might return before all assets in the given load config are loaded.
> The assets are only guaranteed to be ready when the callback described above is called.

You can also pass two more callbacks to `Aura.loadAssets()` that are called whenever an asset fails to load or is loaded:
```haxe
Aura.loadAssets(loadConfig, () -> {
	trace("All assets loaded!");
}, (assetName: String, error: Null<kha.AssetError>) -> {
	trace('Failed to load $assetName: ${error?.error}');
}, (numLoadedAssets: Int, totalNumAssets: Int, assetName: String) -> {
	trace('Loaded asset $numLoadedAsset of $totalNumAssets ($assetName)');
});
```

## Play sounds

Before you can play a sound, you need to create a channel for it.
A channel maintains the sound's state such as its playback position, it's volume, or effects linked to the sound.
Since channels reside in the audio thread (on platforms that use a separate audio thread), the interaction with a given channel happens by means of a handle object for that channel.
There are two types of sound channels and corresponding handles depending on whether a sound is compressed in memory or not:

```haxe
// Assume these to be loaded already
var myUncompressedSound: kha.Sound;
var myCompressedSound: kha.Sound;

...

// Create channels for the above sounds. The functions return handle objects.
var handleUncomp = Aura.createUncompBufferChannel(myUncompressedSound);
var handleComp = Aura.createCompBufferChannel(myCompressedSound);

// The channel creation functions allow for two more parameters:
var handleUncomp = Aura.createUncompBufferChannel(myUncompressedSound, true); // Enable automatic repeats
var handleUncomp = Aura.createUncompBufferChannel(myUncompressedSound, false, Aura.mixChannels["sfx"]); // Explained further below
```

Once you obtained a handle to a channel, you can use the handle's methods to interact with the sound. For example:
```haxe
handleUncomp.play(); // Start to play the sound
handleUncomp.pause(); // Pause the playback (retains the current playback position for later)
handleUncomp.stop(); // Stop the playback and set the playback position to zero

// It is possible to "retrigger" a sound, which is equivalent to stop() + play() in succession:
handleUncomp.play(true);

handleUncomp.setVolume(0.5); // Make the channel's playback half as loud as the default volume
```

## Channel hierarchies

In many situations it makes sense to group channels together in order to control them together.
For example, you might want to allow the player of your game to set the sound effect volume independent of the volume of the background music, or you might want to add an effect to a group of sounds.

A group of sounds is called a MixChannel in Aura.
```haxe
// A MixChannel can have a name (optional, here: sfx).
// If you pass a name, the name needs to be unique.
var handleSFX = Aura.createMixChannel("sfx");
var handleNamelessMixChannel = Aura.createMixChannel();

// To route a channel into a MixChannel, call `setMixChannel()` on its handle:
handleUncomp.setMixChannel(handleNamelessMixChannel);

// MixChannels can be routed into other MixChannels in order to form a hierarchy:
handleUncomp.setMixChannel(handleSFX);

// Aura has a predefined MixChannel for the master output.
// To make a channel audible, it needs to be routed (directly or indirectly) to
// the master channel.
handleSFX.setMixChannel(Aura.masterChannel);

// Set the sound effect (sfx) volume to 0.5 to make all sound effects play half as loud:
handleSFX.setVolume(0.5);
```

By default, all *sound* channels are already routed to the master output.
As a shortcut, it is possible to pass a handle to the MixChannel when creating a sound channel:
```haxe
// Create a new channel handle for `someAlreadyLoadedSound` and mix the output
// of that channel into the sfx (sound effects) channel
Aura.createUncompBufferChannel(someAlreadyLoadedSound, false, handleSFX);
```

You can obtain handles for named MixChannels by means of `Aura.mixChannels`:
```haxe
Aura.createUncompBufferChannel(someAlreadyLoadedSound, false, Aura.mixChannels["sfx"]);
```

## Effects

Aura comes with a few built-in effects that you can insert on a given channel by means of `addInsert()`:

```haxe
import aura.dsp.Filter;

// Example: lowpass filter that attenuates high frequencies (12 dB/octave)
var lowPass = new Filter(LowPass);
lowPass.setCutoffFreq(1000); // Frequency in Hertz

handleUncomp.addInsert(lowPass);
```

To implement your own effects, subclass the `aura.dsp.DSP` class.

## Spatialization

By default, sounds are played without any distance attenuation or direction.
Spatialization of sound sources is implemented by means of `Panner` objects that are linked to a channel.


### StereoPanner
The `StereoPanner` adjusts the balance of the left and right output.
This is the simplest way of achieving directionality and should be sufficient in many cases.

```haxe
import aura.dsp.panner.StereoPanner;

var mySoundHandle = Aura.createUncompBufferChannel(mySound);
var panner = StereoPanner(mySoundHandle);
```

The balance can be set directly:
```haxe
// Some utility constants
panner.setBalance(LEFT); // The sound is only emitted on the left output
panner.setBalance(CENTER); // Default
panner.setBalance(RIGHT); // The sound is only emitted on the right output

// Set angle in degrees between -90 (left) and 90 (right)
// You can also use Rad(value) for radians in [-pi/2, pi/2]
panner.setBalance(Deg(30));
```

It is also possible to compute the balance based on a position in 3D space.
This also requires Aura to track the position and view orientation of the "listener" in the same space in order to compute the relative positioning between the listener and a sound source.
```haxe
// Set the 3D location and view direction of the listener. You need to do this
// every time that there is a change in the listener's position or orientation
// (i.e., usually every frame in a game).

var cam = getCurrentCamera(); // <-- dummy function that might already exist in your application
Aura.listener.set(cam.worldPosition, cam.lookVector, cam.rightVector);

// Set the 3D position of the sound
mySoundHandle.panner.setLocation(new aura.math.Vec3(-1.0, 1.0, 0.2));

// This also works for Kha and Iron vector types!
// Aura's own Vec3 type can be implicitly converted from and to Kha or Iron
// vectors (3D and 4D).
mySoundHandle.panner.setLocation(new kha.math.FastVector3(-1.0, 1.0, 0.2));
mySoundHandle.panner.setLocation(new iron.math.Vec3(-1.0, 1.0, 0.2));

// Whenever you update the listener position/orientation and/or the sound
// position, you need to manually apply the changes (this avoids needless
// recomputations in the background). Only with a call to update3D() the
// changes actually become audible!
mySoundHandle.panner.update3D();
```

### HRTFPanner

Head-related Transfer Functions (HRTFs) allow for much more realistic albeit computationally more demanding playback.
They emulate the impact of the head and ears of a listener.
See https://github.com/MoritzBrueckner/aura/wiki/HRTFs for basic usage instructions.

When using a HRTFPanner, you need to update the listener and the panner's location as shown in the StereoPanner example above.

# Platform Support

Thanks to Haxe and Kha, Aura runs almost everywhere!

The following targets were tested so far:

| Target | Tested environments | Supported | Notes |
| --- | --- | :---: | --- |
| [Armorcore](https://github.com/armory3d/armorcore) (Krom) | Windows 10 | ✔ | |
| HTML5 | Electron, Firefox | ✔ | - No dedicated audio thread for non-streaming playback<br>- If `kha.SystemImpl.mobileAudioPlaying` is true, streamed playback is not included in the Aura mix pipeline (no DSP etc.) |
| Hashlink/C | Windows 10 | ✔ | |
| hxcpp | Windows 10 | ✔ | |

# License

This work is licensed under multiple licences, which are specified at [`.reuse/dep5`](.reuse/dep5) (complying to the [REUSE recommendations](https://reuse.software/)). The license texts can be found in the [`LICENSES`](LICENSES) directory, or in case of submodules in their respective repositories.

**Short summary**:

- The entire source code in [`Sources/aura`](Sources/aura) is licensed under the Zlib license which is a very permissive license also used by Kha and Armory at the time of writing this. This is the important license for you if you include Aura code in your project.
- This readme file and other configuration files are licensed under CC0-1.0.
- All files in [`.img/`](.img) are licensed under CC-BY-4.0.

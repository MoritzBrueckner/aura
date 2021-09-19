![aura_banner.png](.img/aura_banner_bright.png)

*Aura* is a fast and lightweight 3D audio engine for [Kha](https://kha.tech/) to ease creating realistic sound atmospheres for your games and applications.

# Table of Content
- [Features](#features)
- [Installation](#installation)
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
- Extendable DSP system – easily write your own filters

# Installation

In your project directory, create a folder called `Libraries`. Then, open a command line in that folder and execute the following command (Git must be installed on your machine):

```
git clone https://github.com/MoritzBrueckner/aura.git
```

Then, add the following line to your project's `khafile.js` (if you're using [Armory](https://armory3d.org/), you can skip this step):

```js
project.addLibrary('aura');
```

If you're using Iron, but not Armory, please also add the following to your Khafile to be able to use Iron's vector classes with Aura:

```js
project.addDefine("AURA_WITH_IRON");
```

# Usage

- Load sounds (and automatically uncompress them when needed):

  ```haxe
  import aura.Aura;

  ...

  var loadConfig: AuraLoadConfig = {
      uncompressed: [  // <-- List of sounds to uncompress
          "MySoundFile",
      ],
      compressed: [  // <-- List of sounds to remain compressed
          "AnotherSoundFile",
      ]
  };

  Aura.init(); // <-- Don't forget this!

  Aura.loadSounds(loadConfig, () -> {
      // You can access the loaded sounds with `Aura.getSound()`
      var mySound: kha.Sound = Aura.getSound("MySoundFile");
  });
  ```

- Play a sound:

  ```haxe
  // Plays the sound `mySound` without repeat on the master channel
  Aura.play(mySound);

  // Plays the sound `mySound` with repeat on the master channel
  Aura.play(mySound, true);

  // Plays the sound `mySound` without repeat on the predefined fx channel
  Aura.play(mySound, false, Aura.mixChannels["fx"]);

  // You can also stream sounds directly from disk. Whether a sound can be
  // streamed highly depends on the target and whether the sound is compressed
  // or not. Please consult the Kha sources if in doubt.
  Aura.stream(mySound, false, Aura.mixChannels["music"]);
  ```

  `Aura.play()` and `Aura.stream()` both return a [`Handle`](https://github.com/MoritzBrueckner/aura/blob/master/Sources/aura/Handle.hx) object with which you can control the playback and relevant parameters.

- Create a `MixChannel` to control a group of sounds:

  ```haxe
  // Create a channel for all voices for example.
  // The channel can also be accessed with `Aura.mixChannels["voice"]`
  var voiceChannel = Aura.createMixChannel("voice");

  // Mix the output of `voiceChannel` into the master channel
  Aura.masterChannel.addInputChannel(voiceChannel);

  Aura.play(mySound, false, voiceChannel);
  ```

- Add a lowpass filter to the master channel:

  ```haxe
  import aura.dsp.Filter;

  ...

  Aura.play(mySound);

  var lowPass = new Filter(LowPass);
  lowPass.setCutoffFreq(1000); // Frequency in Hertz

  // Aura.masterChannel is short for Aura.mixChannels["master"]
  Aura.masterChannel.addInsert(lowPass);

  ```

- 2D sound:

  ```haxe
  var mySoundHandle = Aura.play(mySound);

  // Some utility constants
  mySoundHandle.setBalance(LEFT);
  mySoundHandle.setBalance(CENTER); // Default
  mySoundHandle.setBalance(RIGHT);

  // Set angle in degrees between -90 (left) and 90 (right)
  // You can also use Rad(value) for radians in [-pi/2, pi/2]
  mySoundHandle.setBalance(Deg(30));
  ```

- 3D sound:

  ```haxe
  var cam = getCurrentCamera(); // <-- dummy function
  var mySoundHandle = Aura.play(mySound);

  // Set the 3D location and view direction of the listener
  Aura.listener.set(cam.worldPosition, cam.look, cam.right);

  // Set the 3D location of the sound independent of the math API used
  mySoundHandle.setLocation(new kha.math.FastVector3(-1.0, 1.0, 0.2));
  mySoundHandle.setLocation(new iron.math.Vec3(-1.0, 1.0, 0.2));
  mySoundHandle.setLocation(new aura.math.Vec3(-1.0, 1.0, 0.2));

  // Apply the changes to the sound to make them audible (!)
  mySoundHandle.update3D();

  // Switch back to 2D sound. The sound's saved location will not be reset, but
  // you won't hear it at that location anymore.
  mySoundHandle.reset3D();
  ```

  Aura's own `Vec3` type can be implicitly converted from and to Kha or Iron vectors (3D and 4D)!

# Platform Support

Thanks to Haxe and Kha, Aura runs almost everywhere!

The following targets were tested so far:

| Target | Tested environments | Supported | Notes |
| --- | --- | :---: | --- |
| [Armorcore](https://github.com/armory3d/armorcore) (Krom) | Windows | ✔ | |
| HTML5 | | ✔ | - No dedicated audio thread for non-streaming playback<br>- If `kha.SystemImpl.mobileAudioPlaying` is true, streamed playback is not included in the Aura mix pipeline (no DSP etc.) |
| Hashlink/C | Windows | ✔ | |
| hxcpp | Windows | ✔ | |

# License

This work is licensed under multiple licences, which are specified at [`.reuse/dep5`](.reuse/dep5) (complying to the [REUSE recommendations](https://reuse.software/)). The license texts can be found in the [`LICENSES`](LICENSES) directory.

**Short summary**:

- The entire source code in [`Sources/aura`](Sources/aura) is licensed under the Zlib license which is a very permissive license also used by Kha and Armory at the time of writing this. This is the important license for you if you include Aura code in your project.
- This readme file and other configuration files are licensed under CC0-1.0.
- All files in [`.img/`](.img) are licensed under CC-BY-4.0.

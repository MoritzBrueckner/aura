![aura_banner.png](.img/aura_banner_bright.png)

*Aura* is a fast and lightweight 3D audio engine for [Kha](https://kha.tech/) to ease creating realistic sound atmospheres for your games and applications.

# Features

- Multiple attenuation models for 3D sound
- Mix busses for modifying groups of sounds together
- Doppler effect
- Built-in [DSP](https://en.wikipedia.org/wiki/Digital_signal_processing) filters:
  - High-/band-/lowpass filter
  - Haas effect
- Extendable DSP system – easily write your own filters

# Installation

In your project directory, create a folder called `Libraries`. Then, open a command line in that folder and execute the following command:

```
git clone https://gitlab.com/MoritzBrueckner/aura.git
```

Then, add the following line to your project's `khafile.js` (if you're using [Armory](https://armory3d.org/), you can skip this step):

```js
project.addLibrary('aura');
```

# Usage

- Load sounds (and automatically uncompress them when needed):

  ```haxe
  import aura.Aura;

  ...

  var sounds: AuraLoadConfig = {
      uncompressed: [  // <-- List of sounds to uncompress
          "MySoundFile",
      ],
      compressed: [  // <-- List of sounds to remain compressed
          "AnotherSoundFile",
      ]
  };

  Aura.loadSounds(sounds, () -> {
      // All the code inside {} is executed after the sounds were loaded and uncompressed

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
  ```

- Create a `MixerChannel` to control a group of sounds:

  ```haxe
  import aura.channels.MixerChannel;

  ...

  var voiceChannel = MixerChannel();
  // Mix the output of `voiceChannel` into the master channel
  Aura.masterChannel.addInputChannel(voiceChannel);
  ```

- Add a lowpass filter to the master channel:

  ```haxe
  import aura.dsp.Filter;

  ...

  Aura.play(mySound);

  var lowPass = new Filter(LowPass);
  lowPass.setCutoffFreq(1000); // Frequency in Hertz

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
  var mySoundHandle = Aura.play(mySound);

  // Set the 3D location of the sound
  mySoundHandle.location.x = -1.0;
  mySoundHandle.location.y = 1.0;
  mySoundHandle.location.z = 0.2;

  // Set the 3D location of the listener
  Aura.listener.location.x = 2.0;

  // Apply the changes to make them audible
  mySoundHandle.update3D();
  ```

# Platform Support

Thanks to Haxe and Kha, Aura runs almost everywhere!

The following targets were tested:

| Target | Tested environments | Support | Notes |
| --- | --- | :---: | --- |
| [Armorcore](https://github.com/armory3d/armorcore) (Krom) | Windows | ✔ | |
| HTML5 | | ✔ | - No dedicated audio thread for non-streaming playback<br>- If `kha.SystemImpl.mobileAudioPlaying` is true, streamed playback is not included in the Aura mix pipeline (no DSP etc.) |
| Hashlink/C | Windows | ❌ | Waiting for https://github.com/Kode/Kha/pull/1361 |
| hxcpp | Windows | ✔ | |

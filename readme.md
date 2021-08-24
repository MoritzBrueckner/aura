![aura_banner.png](.gitlab/aura_banner.png)

*Aura* is a fast and lightweight 3D audio engine for [Kha](https://kha.tech/) to ease creating realistic sound atmospheres for your games and applications.

# Features

- Multiple attenuation models for 3D sound
- Mix busses for modifying groups of sounds together
- Doppler effect
- Built-in DSP filters:
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
      mySound: kha.Sound = Aura.getSound("MySoundFile");
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
  var mySoundChannel = Aura.play(mySound);

  // Some utility constants
  mySoundChannel.balance = LEFT;
  mySoundChannel.balance = CENTER; // Default
  mySoundChannel.balance = RIGHT;

  // Set angle in degrees between -90 (left) and 90 (right)
  // You can also use Rad(value) for radians in [-pi/2, pi/2]
  mySoundChannel.balance = Balance.fromAngle(Deg(30));
  ```

- 3D sound:

  ```haxe
  var mySoundChannel = Aura.play(mySound);

  // Set the 3D location of the sound
  mySoundChannel.location.x = -1.0;
  mySoundChannel.location.y = 1.0;
  mySoundChannel.location.z = 0.2;

  // Set the 3D location of the listener
  Aura.listener.location.x = 2.0;

  // Apply the changes to make them audible
  mySoundChannel.update3D();
  ```

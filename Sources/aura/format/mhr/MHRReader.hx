/**
	Specification: https://github.com/kcat/openal-soft/blob/master/docs/hrtf.txt
**/

package aura.format.mhr;

import haxe.Int64;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;

import aura.types.HRTF;

using aura.format.InputExtension;

/**
	Loads MHR HRTF Version 3 files into an `HRTF` object.
**/
class MHRReader {
	var inp: BytesInput;

	public function new(bytes: Bytes) {
		this.inp = new BytesInput(bytes);
		inp.bigEndian = false;
	}

	public function read(): HRTF {
		final magic = inp.readString(8, UTF8);
		if (magic != "MinPHR03") {
			throw "File is not a valid MHR HRTF Version 3 file!";
		}

		final sampleRate = Int64.toInt(inp.readUInt32());

		final channelType = inp.readByte();
		final channels = channelType + 1;

		// Samples per HRIR (head related impulse response)
		final hrirSize = inp.readByte();

		// Number of fields used by the data set. Each field represents a
		// set of points for a given distance.
		final fieldCount = inp.readByte();

		final fields = new Vector<Field>(fieldCount);
		var hrirCount = 0;
		for (i in 0...fieldCount) {
			final field = new Field();
			field.distance = inp.readUInt16();
			field.evCount = inp.readByte();
			field.azCount = new Vector<Int>(field.evCount);
			var fieldHrirCount = 0;

			for (j in 0...field.evCount) {
				field.azCount[j] = inp.readByte();
				hrirCount += field.azCount[j];
				fieldHrirCount += field.azCount[j];
			}

			field.hrirCount = fieldHrirCount;

			fields[i] = field;
		}

		// Read actual HRIR samples into coeffs
		for (i in 0...fieldCount) {
			final field = fields[i];
			final hrirs = new Vector<HRIR>(field.hrirCount);
			field.hrirs = hrirs;

			for (j in 0...field.hrirCount) {
				// Create individual HRIR
				final hrir = hrirs[j] = new HRIR();

				hrir.coeffs = new Vector<Float>(hrirSize);
				for (s in 0...hrirSize) {
					final coeff = inp.readInt24();
					// 8388608 = 2^23
					hrir.coeffs[s] = coeff / (coeff < 0 ? 8388608.0 : 8388607.0);
				}
			}
		}

		// Read per-HRIR delay
		for (i in 0...fieldCount) {
			final field = fields[i];

			for (j in 0...field.hrirCount) {
				final hrir = field.hrirs[j];

				hrir.delays = new Vector<Float>(channels);
				for (ch in 0...channels) {
					// 6.2 fixed point
					final delayRaw = inp.readByte();
					final delayIntPart = delayRaw >> 2;
					final delayFloatPart = isBitSet(delayRaw, 1) * 0.5 + isBitSet(delayRaw, 0) * 0.25;
					hrir.delays[ch] = delayIntPart + delayFloatPart;
				}
			}
		}

		return {
			sampleRate: sampleRate,
			numChannels: channels,
			hrirSize: hrirSize,
			hrirCount: hrirCount,
			fields: fields,
		};
	}

	inline function isBitSet(byte: Int, position: Int): Int {
		return (byte & (1 << position) == 0) ? 0 : 1;
	}
}

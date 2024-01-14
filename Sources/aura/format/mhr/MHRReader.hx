/**
	Specification:
	V1: https://github.com/kcat/openal-soft/blob/be7938ed385e18c7800c663672262bb2976aa734/docs/hrtf.txt
	V2: https://github.com/kcat/openal-soft/blob/0349bcc500fdb9b1245a5ddce01b2896bcf9bbb9/docs/hrtf.txt
	V3: https://github.com/kcat/openal-soft/blob/3ef4bffaf959d06527a247faa19cc869781745e4/docs/hrtf.txt
**/

package aura.format.mhr;

import haxe.Int64;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesInput;

import kha.arrays.Float32Array;

import aura.types.HRTF;

using aura.format.InputExtension;

/**
	Load MHR HRTF files (format versions 1–3 are supported) into `HRTF` objects.
**/
class MHRReader {

	public static function read(bytes: Bytes): HRTF {
		final inp = new BytesInput(bytes);
		inp.bigEndian = false;

		final magic = inp.readString(8, UTF8);
		final version = versionFromMagic(magic);

		final sampleRate = Int64.toInt(inp.readUInt32());
		final sampleType = switch (version) {
			case V1: SampleType16Bit;
			case V2: inp.readByte();
			case V3: SampleType24Bit;
		}

		final channelType = switch (version) {
			case V1: 0; // mono
			case V2 | V3: inp.readByte();
		}
		final channels = channelType + 1;

		// Samples per HRIR (head related impulse response) per channel
		final hrirSize = inp.readByte();

		// Number of fields used by the data set. Each field represents a
		// set of points for a given distance.
		final fieldCount = version == V1 ? 1 : inp.readByte();

		final fields = new Vector<Field>(fieldCount);
		var totalHRIRCount = 0;
		for (i in 0...fieldCount) {
			final field = new Field();

			// 1000mm is arbitrary, but it doesn't matter since the interpolation
			// can only access one distance anyway...
			field.distance = version == V1 ? 1000 : inp.readUInt16();
			field.evCount = inp.readByte();
			field.azCount = new Vector<Int>(field.evCount);
			field.evHRIROffsets = new Vector<Int>(field.evCount);

			var fieldHrirCount = 0;
			for (j in 0...field.evCount) {
				// Calculate the offset into the HRIR arrays. Different
				// elevations may have different amounts of azimuths/HRIRs
				field.evHRIROffsets[j] = fieldHrirCount;

				field.azCount[j] = inp.readByte();
				fieldHrirCount += field.azCount[j];
			}
			field.hrirCount = fieldHrirCount;
			totalHRIRCount += fieldHrirCount;

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

				hrir.coeffs = new Float32Array(hrirSize * channels);
				switch (sampleType) {
					case SampleType16Bit:
						for (s in 0...hrirSize) {
							final coeff = inp.readInt16();
							// 32768 = 2^15
							hrir.coeffs[s] = coeff / (coeff < 0 ? 32768.0 : 32767.0);
						}

					case SampleType24Bit:
						for (s in 0...hrirSize) {
							final coeff = inp.readInt24();
							// 8388608 = 2^23
							hrir.coeffs[s] = coeff / (coeff < 0 ? 8388608.0 : 8388607.0);
						}
				}
			}
		}

		// Read per-HRIR delay
		var maxDelayLength = 0.0;
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
					final delay = delayIntPart + delayFloatPart;
					hrir.delays[ch] = delay;
					if (delay > maxDelayLength) {
						maxDelayLength = delay;
					}
				}
			}
		}

		// This should error if uncommented, check if we have reached the end of
		// the file.
		// inp.readByte();

		return {
			sampleRate: sampleRate,
			numChannels: channels,
			hrirSize: hrirSize,
			hrirCount: totalHRIRCount,
			fields: fields,
			maxDelayLength: maxDelayLength
		};
	}

	static inline function isBitSet(byte: Int, position: Int): Int {
		return (byte & (1 << position) == 0) ? 0 : 1;
	}

	static inline function versionFromMagic(magic: String): MHRVersion {
		return switch (magic) {
			case "MinPHR01": V1;
			case "MinPHR02": V2;
			case "MinPHR03": V3;
			default:
				throw 'File is not an MHR HRTF file! Unknown magic string "$magic".';
		}
	}
}

private enum abstract SampleType(Int) from Int {
	var SampleType16Bit;
	var SampleType24Bit;
}

private enum abstract MHRVersion(Int) {
	var V1;
	var V2;
	var V3;
}

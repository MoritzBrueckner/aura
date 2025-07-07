/**
	Ogg layout:
	https://en.wikipedia.org/wiki/Ogg#Page_structure

	Vorbis layout:
	https://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-610004.2
	https://wiki.xiph.org/OggVorbis
**/

package aura.format.audio;

import haxe.io.Bytes;
import haxe.io.BytesInput;

using aura.format.InputExtension;

class OggVorbisReader {

	static inline final OGG_PAGE_HEADER_TYPE_BEG_OF_STREAM = 2;
	static inline final VORBIS_PACKET_TYPE_IDENTIFICATION = 1;

	final inp: BytesInput;

	final firstSegmentPosition = 0;
	final segmentTable: Bytes;

	public inline function new(bytes: Bytes) {
		this.inp = new BytesInput(bytes);
		inp.bigEndian = false;

		final magic = inp.readString(4, haxe.io.Encoding.UTF8);
		if (magic != "OggS") {
			throw "Cannot read .ogg file, file does not start with 'OggS' magic";
		}

		inp.position += 1; // Skip version

		final oggHeaderType = inp.readByte();
		if (oggHeaderType != OGG_PAGE_HEADER_TYPE_BEG_OF_STREAM) {
			throw "Cannot read .ogg file, first header type was expected to be 'Beginning Of Stream'";
		}

		inp.position += 8; // Skip granule position
		inp.position += 4; // Skip bitstream serial number

		final pageSequenceNumber = inp.readUInt32();
		if (pageSequenceNumber != 0) {
			throw "Cannot read .ogg file, first page sequence number was expected to be 0";
		}

		inp.position += 4; // Skip checksum (for now)

		final numPageSegments = inp.readByte();
		if (numPageSegments == 0) {
			throw "Cannot read .ogg file, first page has no segments";
		}

		segmentTable = Bytes.alloc(numPageSegments);
		inp.readFullBytes(segmentTable, 0, numPageSegments);

		firstSegmentPosition = inp.position;

		final packetType = inp.readByte();
		if (packetType != VORBIS_PACKET_TYPE_IDENTIFICATION) {
			throw "Cannot read .ogg file, Vorbis identification header expected";
		}

		final vorbisIdentifier = inp.readString(6, haxe.io.Encoding.UTF8);
		if (vorbisIdentifier != "vorbis") {
			throw "Cannot read .ogg file, only Ogg Vorbis files are supported";
		}

		// See https://xiph.org/vorbis/doc/Vorbis_I_spec.html#x1-610004.2, version must be 0
		final version = inp.readUInt32();
		if (version != 0) {
			throw "Cannot read .ogg file, Vorbis version field expected to be 0";
		}
	}

	public function getNumChannels(): Int {
		inp.position = firstSegmentPosition + 1 + 6 + 4; // Skip packet type + vorbis identifier + version

		final numChannels = inp.readByte();
		assert(Critical, numChannels > 0);

		return numChannels;
	}
}

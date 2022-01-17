package aura.utils;

import kha.Image;
import kha.arrays.Float32Array;
import kha.graphics2.Graphics;

import aura.utils.MathUtils;

using StringTools;

class Debug {
	static var id = 0;

	/**
		Generates GraphViz/dot code to draw the channel tree for debugging. On
		html5 this code is copied to the clipboard, on other targets it is
		copied to the console but might be cut off (so better use html5 for
		that).
	**/
	public static function debugTreeViz() {
		#if AURA_DEBUG
			final content = new StringBuf();

			content.add("digraph Aura_Tree_Snapshot {\n");

				content.add('\tranksep=equally;\n');
				content.add('\trankdir=BT;\n');
				content.add('\tnode [fontname = "helvetica"];\n');

				addTreeToViz(content, Aura.masterChannel);

			content.add("}");

			copyToClipboard(content.toString());
		#else
			trace("Please build with 'AURA_DEBUG' flag!");
		#end
	}

	#if AURA_DEBUG
	static function addTreeToViz(buf: StringBuf, channelHandle: Handle) {
		buf.add('\t${id++} [\n');
		buf.add('\t\tshape=plaintext,\n');
		buf.add('\t\tlabel=<<table border="1" cellborder="0" style="rounded">\n');

		buf.add('\t\t\t<tr><td colspan="2"><b>${Type.getClassName(Type.getClass(channelHandle))}</b></td></tr>\n');
		buf.add('\t\t\t<tr><td colspan="2">${Type.getClassName(Type.getClass(@:privateAccess channelHandle.channel))}</td></tr>\n');
		buf.add('\t\t\t<hr/>\n');
		buf.add('\t\t\t<tr><td><i>Tree level</i></td><td>${@:privateAccess channelHandle.channel.treeLevel}</td></tr>\n');
		buf.add('\t\t\t<hr/>\n');

		for (key => val in channelHandle.getDebugAttrs()) {
			buf.add('\t\t\t<tr><td><i>$key</i></td><td>$val</td></tr>');
		}
		buf.add('\t\t</table>>\n');
		buf.add('\t];\n');

		final thisID = id - 1;
		if (Std.isOfType(channelHandle, MixChannelHandle)) {
			var mixHandle: MixChannelHandle = cast channelHandle;
			for (inputHandle in mixHandle.inputHandles) {
				final inputID = id;

				addTreeToViz(buf, inputHandle);
				buf.add('\t${inputID} -> ${thisID};\n');
			}
		}
	}

	static function copyToClipboard(text: String) {
		#if (kha_html5 || kha_debug_html5)
		js.Browser.navigator.clipboard.writeText(text)
			.then(
				(_) -> { trace("Debug tree code has been copied to clipboard."); },
				(err) -> {
					trace('Debug tree code could not be copied to clipboard, writing to console instead. Reason: $err');
					trace(text);
				}
			);
		#else
		trace(text);
		#end
	}

	public static function drawWaveform(buffer: Float32Array, g: Graphics, x: Float, y: Float, w: Float, h: Float) {
		g.begin(false);

		g.opacity = 1.0;
		g.color = kha.Color.fromFloats(0.176, 0.203, 0.223);
		g.fillRect(x, y, w, h);

		final borderSize = 2;
		g.color = kha.Color.fromFloats(0.099, 0.099, 0.099);
		g.drawRect(x + borderSize * 0.5, y + borderSize * 0.5, w - borderSize, h - borderSize, borderSize);

		g.color = kha.Color.fromFloats(0.898, 0.411, 0.164);

		final deinterleavedLength = Std.int(buffer.length / 2);
		final numLines = buffer.length - 1;
		final stepSize = w / numLines;
		final innerHeight = h - 2 * borderSize;
		for (c in 0...2) {
			if ( c == 1 ) g.color = kha.Color.fromFloats(0.023, 0.443, 0.796);
			for (i in 0...deinterleavedLength - 1) {
				final idx = i + c * deinterleavedLength;
				final y1 = y + borderSize + (1 - clampF(buffer[idx] * 0.5 + 0.5, 0, 1)) * innerHeight;
				final y2 = y + borderSize + (1 - clampF(buffer[idx + 1] * 0.5 + 0.5, 0, 1)) * innerHeight;
				g.drawLine(x + idx * stepSize, y1, x + (idx + 1) * stepSize, y2);
			}
		}

		g.color = kha.Color.fromFloats(0.023, 0.443, 0.796);
		g.opacity = 0.5;
		g.drawLine(x + w / 2, y, x + w / 2, y + h, 2);

		g.end();
	}

	public static function createRenderTarget(w: Int, h: Int): Image {
		return Image.createRenderTarget(Std.int(w), Std.int(h), null, NoDepthAndStencil, 1, 0);
	}
	#end
}

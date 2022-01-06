package aura.utils;

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
	#end
}

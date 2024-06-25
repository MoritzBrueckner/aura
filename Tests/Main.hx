package;

import utest.Runner;
import utest.ui.Report;

#if instrument
import instrument.Instrumentation;
#end

class Main {
	static function main() {

		kha.System.start({title: "Aura Unit Tests", width: 1024, height: 768}, (window: kha.Window) -> {

			replaceConsoleFunctions();

			#if (AURA_ASSERT_LEVEL!="Debug")
				trace("Warning: Running tests below highest assertion level, some tests might erroneously succeed");
			#end

			kha.Assets.loadEverything(() -> {
				kha.audio2.Audio.samplesPerSecond = 44100;
				aura.Aura.init();

				var runner = new Runner();
				runner.addCases(auratests, true);

				// addCases() only allows one class per file (https://github.com/haxe-utest/utest/blob/f759c0aa257aa723b3dd607cf7cb53d16194d13f/src/utest/Runner.hx#L171),
				// so we manually add classes here where this is not the case
				runner.addCase(new auratests.dsp.TestSparseConvolver.TestSparseImpulseBuffer());

				runner.onComplete.add((_) -> {
					#if instrument
						Instrumentation.endInstrumentation(Coverage);
					#end
				});

				Report.create(runner);
				// new utest.ui.text.PrintReport(runner);
				runner.run();
			});

		});
	}

	/**
		In Kha applications, `console.log()` calls called by `trace` are called
		from within the renderer process which prevents them from showing up in
		the console (instead they only show up in the devtools console).

		A possible workaround is to run electron with `--enable-logging`,
		but this will show the traces in a bunch of irrelevant and noisy debug
		information and on Windows a bunch of terminal windows are opened if
		electron is not directly called from the shell. So instead, we send
		traces to the main thread and then log them there.

		**See:**
		- Log in main process/renderer process:
			- https://stackoverflow.com/a/31759944/9985959

		- Overriding console functions:
			- https://stackoverflow.com/a/30197398/9985959

		- Electron opening multiple empty terminals on Windows:
			- https://github.com/electron/electron/issues/3846
			- https://github.com/electron/electron/issues/4582
			- https://github.com/electron-userland/spectron/issues/60#issuecomment-482070086
	**/
	static function replaceConsoleFunctions() {
		#if kha_debug_html5
			final oldConsole: Dynamic = js.Syntax.code("window.console");

			function log(text: Dynamic) {
				oldConsole.log(text);
				js.Syntax.code("window.electron.logToMainProcess('log', {0})", text);
			}

			function info(text: Dynamic) {
				oldConsole.info(text);
				js.Syntax.code("window.electron.logToMainProcess('info', {0})", text);
			}

			function warn(text: Dynamic) {
				oldConsole.warn(text);
				js.Syntax.code("window.electron.logToMainProcess('warn', {0})", text);
			}

			function error(text: Dynamic) {
				oldConsole.error(text);
				js.Syntax.code("window.electron.logToMainProcess('error', {0})", text);
			}

			js.Syntax.code("window.console = {log: {0}, info: {1}, warn: {2}, error: {3}}", log, info, warn, error);
		#end
	}
}

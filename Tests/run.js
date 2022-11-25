const path = require("path");

const utils = require(path.join(__dirname, "utils.js"));

async function run() {
	const khaPath = utils.getEnvVarSafe("KHA_PATH");
	const electron_bin = utils.getEnvVarSafe("ELECTRON_BIN");

	khamake_args = [
		path.join(khaPath, "make"),
		"debug-html5",
		"--debug"
	]

	electron_args = [
		"--no-sandbox",
		"--force-device-scale-factor=1",
		// "--enable-logging",
		// "--trace-warnings",
		"--force_low_power_gpu",
		"build/debug-html5/electron.js"
	]

	await utils.spawnCommand("node", khamake_args, true);
	await utils.spawnCommand(electron_bin, electron_args, true);
}

(async () => {
	await run();
})();

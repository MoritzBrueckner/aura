const fs = require("fs");
const path = require("path");

const utils = require(path.join(__dirname, "utils.js"));

const useInstrument = true;

async function run() {
	if (!fs.existsSync(".haxelib/")) {
		await utils.install_deps();
	}

	const project = new Project('Aura Tests');

	project.addSources(".");

	await project.addProject("../");

	project.addLibrary("utest");
	project.addDefine("UTEST_PRINT_TESTS");

	// Easier to match problems with the problem matcher below, enable if
	// running headless in command line (this will prevent displaying the html output)
	// project.addDefine("UTEST_FAILURE_THROW");

	if (useInstrument) {
		project.addLibrary("instrument");
		project.addDefine("instrument_quiet");
		project.addDefine("coverage-console-package-summary-reporter");
		// project.addDefine("coverage-console-summary-reporter");
		project.addParameter("--macro instrument.Instrumentation.coverage(['aura'], null, ['auratests'])");

		// From https://github.com/HaxeFoundation/hxnodejs/blob/master/extraParams.hxml
		// to fix sys access error on nodejs even if it should work
		// Reference:
		//     https://github.com/AlexHaxe/haxe-instrument/issues/8
		//     https://github.com/HaxeFoundation/hxnodejs/issues/59
		//     https://community.haxe.org/t/using-sys-in-nodejs-target/3702
		// project.addParameter("--macro allowPackage('sys')");
		// project.addParameter("--macro define('nodejs')");
		// project.addParameter("--macro _internal.SuppressDeprecated.run()");
	}

	if (project.targetOptions.html5.expose === undefined) {
		project.targetOptions.html5.expose = "";
	}
	project.targetOptions.html5.expose += "logToMainProcess: (type, text) => electron.ipcRenderer.send('log-main', type, text),";

	project.addParameter("--no-opt");
	project.addParameter("--no-inline");
	project.addParameter('-dce full');

	// project.addParameter("--macro nullSafety('aura', Strict)");
	// project.addParameter("--macro nullSafety('aura', StrictThreaded)");

	project.addDefine("AURA_UNIT_TESTS");
	project.addDefine("AURA_ASSERT_LEVEL=Debug");

	project.addCDefine("KINC_NO_WAYLAND"); // Causes errors in the CI

	callbacks.postBuild = () => {
		fs.copyFileSync("Data/index.html", "build/debug-html5/index.html");

		const electronJSAppend = fs.readFileSync("Data/electron-append.js", "utf8");
		fs.appendFileSync("build/debug-html5/electron.js", "\n\n" + electronJSAppend);
	};

	resolve(project);
}

await run();

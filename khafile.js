const fs = require("fs");

const optickPathKey = "AURA_OPTICK_PATH";

// See https://github.com/Kode/Kha/wiki/Hashlink
const targetsHL = ["windows-hl", "linux-hl", "osx-hl", "android-hl", "ios-hl"];
const targetsCPP = ["windows", "linux", "osx"];
const targetsHTML5 = ["html5", "debug-html5"];

function addBackends(project) {
	project.localLibraryPath = 'Backends';

	let isHL = targetsHL.indexOf(Project.platform) >= 0;

	if (isHL) {
		project.addLibrary("hl");
		project.addDefine("AURA_BACKEND_HL");
		console.log("[Aura] Using HL/C backend");
	}

	const isHTML5 = targetsHTML5.indexOf(Project.platform) >= 0;
	if (isHTML5) {
		// project.addSources('backends/html5');
	}

	project.localLibraryPath = 'Libraries';
}

async function main() {
	const project = new Project('aura');

	project.addSources('Sources');

	if (process.argv.indexOf("-aura-no-backend") == -1) {
		addBackends(project);
	}
	else {
		project.addDefine("AURA_NO_BACKEND");
	}

	const isCPP = targetsCPP.indexOf(Project.platform) >= 0;
	if (isCPP && process.argv.indexOf("--aura-no-simd") == -1) {
		project.addDefine("AURA_SIMD");
	}

	const withOptick = optickPathKey in process.env;
	if (withOptick) {
		const optickPath = process.env[optickPathKey];

		if (fs.existsSync(optickPath)) {
			project.addDefine("AURA_WITH_OPTICK");

			await project.addProject(optickPath);

			// Unfortunately there is no metadata to include a specified header
			// in the cpp file that calls a certain _inlined_ Haxe function, so
			// instead we need to add it everywhere for now (bad workaround)...
			project.addParameter("--macro addGlobalMetadata('aura', '@:headerCode(\"#include <optick.h>\")')");
		}
		else {
			console.warn(`Aura: Path ${optickPath} does not exist, building without Optick support.`);
		}
	}

	resolve(project);
}

await main();

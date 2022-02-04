// See https://github.com/Kode/Kha/wiki/Hashlink
const hl_targets = ["windows-hl", "linux-hl", "osx-hl", "android-hl", "ios-hl"];

function addBackends(project) {
	project.localLibraryPath = 'Backends';

	let on_hl = false;
	for (let hl_target of hl_targets) {
		on_hl |= process.argv.indexOf(hl_target) >= 0;
	}
	if (on_hl) {
		// project.addSources("backends/hl");
		project.addLibrary("hl");
		project.addDefine("AURA_BACKEND_HL");
		console.log("[Aura] Added HL/C backend");
	}

	const on_html5 = process.argv.indexOf("html5") >= 0;
	if (on_html5) {
		// project.addSources('backends/html5');
	}

	project.localLibraryPath = 'Libraries';
}

function main() {
	const project = new Project('aura');

	project.addSources('Sources');

	if (process.argv.indexOf("-aura-no-backend") == -1) {
		addBackends(project);
	} else {
		project.addDefine("AURA_NO_BACKEND");
	}

	resolve(project);
}

main();

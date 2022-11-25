const child_process = require("child_process");

async function spawnCommand(command, args, exitOnErr) {
	exitOnErr = exitOnErr === undefined ? true : exitOnErr;

	const proc = child_process.spawn(command, args);

	proc.stdout.on("data", function (data) {
		console.log(data.toString().trim());
	});

	proc.stderr.on("data", function (data) {
		console.error(data.toString().trim());
	});

	return new Promise(function(resolve, reject) {
		proc.on("close", function (code) {
			if (code == 0) {
				console.log(`Child process exited with code ${code}`);
				resolve();
			} else {
				console.error(`Child process failed with code ${code}`);
				if (exitOnErr) {
					process.exit(code);
				}
				reject();
			}
		});
	});
}

function getEnvVarSafe(varname) {
	const value = process.env[varname];
	if (value === undefined) {
		exitWithError(`Environment variable '${varname}' not set!`)
	}
	return value;
}

function exitWithError(message, exitCode) {
	exitCode = exitCode === undefined ? 1 : exitCode;

	console.error("[Error]  " + message);
	process.exit(exitCode);
}

async function install_deps() {
	console.log("Downloading haxelib dependencies...");
	await spawnCommand("haxelib", ["newrepo"]);
	await spawnCommand("haxelib", ["install", "TestDeps.hxml", "--always"]);
}

module.exports = {
	spawnCommand: spawnCommand,
	getEnvVarSafe: getEnvVarSafe,
	exitWithError: exitWithError,
	install_deps: install_deps,
}

const fs = require("fs");

const auraPath = __dirname.replace(/\\/g, "/");
const libPath = auraPath + "/Libraries";

let project = new Project('aura');

project.addSources('Sources');

// Kha can't include libraries where the sources folder
// isn't called "Sources", so manually include the sources
// here. Also, the hxdsp library includes a Main.hx as an
// example that we need to ignore because it requires another
// library and it would override the project's Main.hx.
callbacks.preHaxeCompilation = () => {
	const hxdspSrc = libPath + "/hxdsp/src/";
	fs.renameSync(hxdspSrc + "Main.hx", hxdspSrc + "Main.temp.txt");
};
callbacks.postHaxeCompilation = () => {
	const hxdspSrc = libPath + "/hxdsp/src/";
	fs.renameSync(hxdspSrc + "Main.temp.txt", hxdspSrc + "Main.hx");
};
project.addSources("Libraries/hxdsp/src");

resolve(project);

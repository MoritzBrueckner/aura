const fs = require("fs");

const auraPath = __dirname.replace(/\\/g, "/");
const libPath = auraPath + "/Libraries";

let project = new Project('aura');

project.addSources('Sources');

// Kha can't include libraries where the sources folder isn't
// called "Sources", so manually include the sources here
project.addSources("Libraries/hxdsp/src");

resolve(project);

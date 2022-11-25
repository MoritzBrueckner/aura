const path = require("path");

const utils = require(path.join(__dirname, "utils.js"));

(async () => {
	await utils.install_deps();
})();

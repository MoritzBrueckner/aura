electron.ipcMain.on('log-main', (event, type, text) => {
	switch (type) {
		case "log":
			console.log(text);
			break;
		case "info":
			console.info(text);
			break;
		case "warn":
			console.warn(text);
			break;
		case "error":
			console.error(text);
			break;
		default:
			throw "Unreachable";
	}
});

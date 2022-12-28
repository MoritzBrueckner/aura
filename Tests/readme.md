# Aura Tests

The `/Tests` directory contains a test suite to test some of Aura's functionality.

Because Kha/Kinc currently cannot run in headless mode (see the relevant
[issue](https://github.com/Kode/Kinc/issues/564)) in targets other than node.js
and the node.js target breaks quite often due to Kha updates, the tests currently
run semi-automatically (i.e. invoked by the user) on the debug-html5 target in Electron.
As a consequence, it is currently not possible to run them in a CI pipeline.

## Setup

Running the tests requires node.js which you probably already have installed
since it is required for running Khamake.

If you are using Armory, you can instead use the node.js executables included
in the SDK at `<sdk-path>/nodejs`.

## Running the Tests

### Using VSCode/VSCodium

1. Add the `/Tests` directory as a folder to your VSCode workspace
   using `File > Add Folder to Workspace`. VSCode unfortunately doesn't search
   for task.json files in subdirectories.

2. Press `F1` or `Ctrl + Shift + P` and select `Tasks: Run Test Task`.

   > **Note**<br>
   > The task automatically picks up the Kha and Electron versions as configured in
   > VSCode.

### From the Command Line

1. Point the environment variable `KHA_PATH` to the root path of the Kha repository.

2. Point the environment variable `ELECTRON_BIN` to an Electron executable.

3. Run the following:
   ```batch
   node run.js
   ```

## Updating Dependencies

The first time the test project is built, all necessary dependencies are
automatically installed. If you want to update them to the newest version,
simply run the following:
```batch
node install_deps.js
```

## Defines

While the tests are run, the define `AURA_UNIT_TESTS` is set and the assertion
level is set to `AURA_ASSERT_LEVEL=Debug`.

package aura;

import haxe.Exception;

import aura.types.HRTF;
import aura.format.mhr.MHRReader;

/**
	Called for successfully loaded assets in `aura.Assets.startLoading`.

	@param asset
		The asset that was successfully loaded.
	@param numLoaded
		The number of already loaded assets at the point of loading `asset`,
		including `asset`.
	@param numTotalAssets
		The size of the asset list `aura.Assets.startLoading()` was called with
		minus the number of assets from that list that already failed loading.

	@see `aura.Assets.startLoading`
**/
typedef AssetLoadedCallback = (asset: Asset, numLoaded: Int, numTotalAssets: Int)->Void;

/**
	Called for assets that failed to load in `aura.Assets.startLoading`.

	@param asset The asset that failed to load.
	@param error Information about the location and reason for the failure.

	@return Specify how to continue following the loading failure.

	@see `aura.Assets.startLoading`
**/
typedef AssetFailedCallback = (asset: Asset, error: kha.AssetError)->ProgressInstruction;

/*
	Workaround to make `Assets.startLoading()` also work with `assetList`
	arguments of type `Array<Sound>` or `Array<HRTF>`, for example.

	Just typing the function parameter as `Array<Asset>` would not work due to
	generic invariance.
*/
typedef AssetList = Iterable<Asset> & {
	public var length(default, null):Int;
}

class Assets {
	static final loadedSounds = new Map<String, Sound>();
	static final loadedHRTFs = new Map<String, HRTF>();

	/**
		Start to load all assets listed in the given `assetList`. The actual
		loading may take place asynchronously (depending on the Kha target).

		The order in which assets are loaded is not guaranteed, do not rely on it.

		The loading progress can be tracked and controlled by means of the
		`onAssetLoaded` and `onAssetFailed` callbacks that are called each time
		loading an asset succeeded or failed, respectively.

		@param assetList
			A list of assets to load.
		@param onAssetLoaded
			Called if an asset in `assetList` was successfully loaded.
			Documentation on the parameters is provided at `AssetLoadedCallback`.

			If loading an asset fails (`aura.Assets.ProgressStatus.FailedAsset`),
			the return value of the callback signals Aura whether to proceed with
			loading assets or whether to abort the process. In all other cases,
			the return value has no significance and is ignored.

		@see `aura.Assets.ProgressStatus`
		@see `aura.Assets.ProgressInstruction`
	**/
	public static function startLoading(assetList: AssetList, onAssetLoaded: AssetLoadedCallback, onAssetFailed: AssetFailedCallback) {
		final loadingState: LoadingState = {
			numLoaded: 0,
			totalAssets: assetList.length,
			abortLoading: false,
		};

		for (asset in assetList) {
			if (loadingState.abortLoading) { return; }
			@:privateAccess asset.startLoading(loadingState, onAssetLoaded, onAssetFailed);
		}
	}

	public static inline function getLoadedSound(assetName: String): Null<Sound> {
		return loadedSounds[assetName];
	}

	static function uncompressSoundIfRequired(sound: kha.Sound, compressionBehavior: CompressionBehavior, done: Null<String>->Void) {
		if (compressionBehavior == KeepCompressed || sound.uncompressedData != null) {
			done(null);
			return;
		}

		if (sound.compressedData == null) {
			done("Sound has no data to uncompress");
			return;
		}

		sound.uncompress(() -> {
			done(null);
		});
	}
}


abstract class Asset {
	public final name: String;

	var isLoaded = false;

	public function new(name: String) {
		this.name = name;
	}

	abstract function startLoading(loadingState: LoadingState, onAssetLoaded: AssetLoadedCallback, onAssetFailed: AssetFailedCallback): Void;
}


/**
	Asset representing a sound file.

	@see `aura.Assets.CompressionBehavior`
**/
@:access(aura.Assets)
@:allow(aura.Assets.Asset)
@:allow(aura.Aura)
class Sound extends Asset {
	final compressionBehavior: CompressionBehavior;

	var khaSound: Null<kha.Sound> = null;

	public function new(name: String, compressionBehavior: CompressionBehavior) {
		super(name);
		this.compressionBehavior = compressionBehavior;
	}

	function startLoading(loadingState: LoadingState, onAssetLoaded: AssetLoadedCallback, onAssetFailed: AssetFailedCallback) {
		kha.Assets.loadSound(name, (_khaSound: kha.Sound) -> {
			if (loadingState.abortLoading) { return; }

			/*
				Krom only uses uncompressedData, silently ignore this since
				Aura.createCompBufferChannel() also handles this case.
			*/
			var effectiveCompressionBehavior = compressionBehavior;
			#if !kha_krom
				if (compressionBehavior == KeepCompressed && _khaSound.compressedData == null) {
					effectiveCompressionBehavior = Uncompress;
				}
			#end

			Assets.uncompressSoundIfRequired(_khaSound, effectiveCompressionBehavior, (error: Null<String>) -> {
				if (loadingState.abortLoading) { return; }

				if (error != null) {
					/*
						Relying on Kha internals ("Description" as name) is bad,
						but there is no good alternative...
					*/
					final desc = Reflect.field(kha.Assets.sounds, name + "Description");
					loadingState.totalAssets--;
					final instruction = onAssetFailed(this, {
						url: desc.files[0],
						error: error
					});
					loadingState.abortLoading = loadingState.abortLoading || instruction == AbortLoading;
				}
				else {
					Assets.loadedSounds[name] = this;
					this.khaSound = _khaSound;
					loadingState.numLoaded++;

					this.isLoaded = true;

					onAssetLoaded(this, loadingState.numLoaded, loadingState.totalAssets);
				}
			});

		}, (error: kha.AssetError) -> {
			if (loadingState.abortLoading) { return; }
			loadingState.totalAssets--;
			loadingState.abortLoading = loadingState.abortLoading || onAssetFailed(this, error) == AbortLoading;
		});
	}
}


@:access(aura.Assets)
@:allow(aura.Assets.Asset)
class HRTF extends Asset {
	var hrtf: Null<HRTFData> = null;

	public function new(name: String) {
		super(name);
	}

	function startLoading(loadingState: LoadingState, onAssetLoaded: AssetLoadedCallback, onAssetFailed: AssetFailedCallback) {
		kha.Assets.loadBlob(name, (blob: kha.Blob) -> {
			if (loadingState.abortLoading) { return; }

			var hrtf: HRTFData;
			try {
				hrtf = MHRReader.read(blob.toBytes());
			}
			catch (e: Exception) {
				final desc = Reflect.field(kha.Assets.blobs, name + "Description");
				loadingState.totalAssets--;
				final instruction = onAssetFailed(this, {
					url: desc.files[0],
					error: e.details() // TODO use own error type that can differentiate between error message and call stack
				});
				loadingState.abortLoading = loadingState.abortLoading || instruction == AbortLoading;
				blob.unload();
				return;
			}
			blob.unload();
			this.hrtf = hrtf;
			Assets.loadedHRTFs[name] = this;
			loadingState.numLoaded++;

			this.isLoaded = true;

			onAssetLoaded(this, loadingState.numLoaded, loadingState.totalAssets);

		}, (error: kha.AssetError) -> {
			if (loadingState.abortLoading) { return; }
			loadingState.totalAssets--;
			loadingState.abortLoading = loadingState.abortLoading || onAssetFailed(this, error) == AbortLoading;
		});
	}
}


@:structInit
class LoadingState {
	public var numLoaded: Int;
	public var totalAssets: Int;
	public var abortLoading: Bool; // TODO use enum with optional unload flag that would unload already loaded assets?
}

/**
	Define how to handle compression after loading an asset.

	@see `aura.Assets.startLoading()`
	@see `aura.Assets.Sound`
**/
enum abstract CompressionBehavior(Int) {
	/** Keep the asset data compressed (if the asset is compressed). **/
	final KeepCompressed;

	/** Automatically uncompress the asset data after loading. **/
	final Uncompress;
}


enum abstract ProgressInstruction(Bool) {
	/** Continue the loading process. **/
	final ContinueLoading = true;

	/**
		Abort the loading process as soon as possible. No further calls to the
		`onAssetLoaded` and `onAssetFailed` callbacks of `aura.Assets.startLoading`
		take place afterwards.
	 **/
	final AbortLoading = false;
}

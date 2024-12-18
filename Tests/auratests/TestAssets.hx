package auratests;

import utest.Assert;

import aura.Assets.Asset;
import aura.Assets.Sound;

class TestAssets extends utest.Test {
	function setup() {}

	function teardown() {}

	function test_startLoading_acceptsCovariantAssetList() {
		/*
			This is not a run-time test, the test passes *if it compiles*!

			It makes sure that startLoading can also be called with Array<Sound>
			for example instead of only Array<Asset>. This is important in cases
			the assetList contains only one item and Haxe automatically infers
			the type.
		*/

		final assetList: Array<Sound> = [
			new aura.Assets.Sound("test", KeepCompressed),
		];

		function onAssetLoaded(asset: aura.Assets.Asset, numLoaded: Int, numTotalAssets: Int) {}
		function onAssetFailed(asset: aura.Assets.Asset, error: kha.AssetError): aura.Assets.ProgressInstruction {
			return ContinueLoading;
		}

		aura.Assets.startLoading(assetList, onAssetLoaded, onAssetFailed);

		Assert.pass();
	}
}

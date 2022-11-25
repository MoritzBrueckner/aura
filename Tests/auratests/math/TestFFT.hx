package auratests.math;

import utest.Assert;

import aura.math.FFT;

import Utils;

@:depends(auratests.types.TestComplexArray)
class TestFFT extends utest.Test {

	function test_bitReverseUint32() {
		// Haxe has some issue with signed/unsigned ints here, so we instead
		// compare the individual strings as bits. This also makes the output in
		// case of assertion failures much nicer to look at.
		Assert.equals(Utils.int32ToBytesString(0xFF000000), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x000000FF, 32)));
		Assert.equals(Utils.int32ToBytesString(0x00FF0000), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x0000FF00, 32)));
		Assert.equals(Utils.int32ToBytesString(0x0000FF00), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x00FF0000, 32)));
		Assert.equals(Utils.int32ToBytesString(0x000000FF), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0xFF000000, 32)));

		Assert.equals(Utils.int32ToBytesString(0xC0000000), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x00000003, 32)));
		Assert.equals(Utils.int32ToBytesString(0x20000000), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x00000004, 32)));

		Assert.equals(Utils.int32ToBytesString(0x00FF0000), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x000000FF, 24)));
		Assert.equals(Utils.int32ToBytesString(0x0000FF00), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x0000FF00, 24)));
		Assert.equals(Utils.int32ToBytesString(0x000000FF), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x00FF0000, 24)));
		Assert.equals(Utils.int32ToBytesString(0x0000FF00), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x000000FF, 16)));
		Assert.equals(Utils.int32ToBytesString(0x00000003), Utils.int32ToBytesString(@:privateAccess aura.math.FFT.bitReverseUint32(0x00000018, 5)));
	}

	function test_RealValuedFFT() {

		final realFFT = new RealValuedFFT(64, 2, 1);

		final inputBuffer = realFFT.getInput(0);
		for (i in 0...realFFT.size) {
			inputBuffer[i] = Math.sin(i / realFFT.size * 2 * Math.PI * 8);
		}

		realFFT.forwardFFT(0, 0);

		var maxIdx = 0;
		var maxVal = realFFT.getOutput(0)[0].real;
		for (i in 1...realFFT.size) {
			final val = realFFT.getOutput(0)[i].real;
			if (val > maxVal) {
				maxVal = val;
				maxIdx = i;
			}
		}
		Assert.equals(8, maxIdx);

		realFFT.inverseFFT(1, 0);

		// Assert that ifft(fft(array)) == array
		for (i in 0...realFFT.size) {
			Assert.floatEquals(realFFT.getInput(0)[i], realFFT.getInput(1)[i]);
		}
	}

	function test_ComplexValuedFFT() {

		final cplxFFT = new ComplexValuedFFT(64, 2, 1);

		final inputBuffer = cplxFFT.getInput(0);
		for (i in 0...cplxFFT.size) {
			inputBuffer[i].real = Math.sin(i / cplxFFT.size * 2 * Math.PI * 8);
			inputBuffer[i].imag = 0.0;
		}

		cplxFFT.forwardFFT(0, 0);

		// var maxIdx = 0;
		// var maxVal = cplxFFT.getOutput(0)[0].real;
		// for (i in 1...cplxFFT.size) {
		// 	final val = cplxFFT.getOutput(0)[i].real;
		// 	if (val > maxVal) {
		// 		maxVal = val;
		// 		maxIdx = i;
		// 	}
		// }
		// Assert.equals(8, maxIdx);

		cplxFFT.inverseFFT(1, 0);

		// Assert that ifft(fft(array)) == array
		for (i in 0...cplxFFT.size) {
			Assert.floatEquals(cplxFFT.getInput(0)[i].real, cplxFFT.getInput(1)[i].real);
			Assert.floatEquals(cplxFFT.getInput(0)[i].imag, cplxFFT.getInput(1)[i].imag);
		}
	}
}

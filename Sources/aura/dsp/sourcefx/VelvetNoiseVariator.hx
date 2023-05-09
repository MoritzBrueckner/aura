package aura.dsp.sourcefx;

import kha.FastFloat;

import aura.dsp.SparseConvolver;
import aura.types.AudioBuffer;
import aura.utils.MathUtils;
import aura.utils.FrequencyUtils;

/**
	Generate infinite variations on short percussive samples on the fly,
	following the technique from the paper linked below.

	The parameters of this effect need careful tweaking. Some examples can be
	found in _Table 1_ in the paper linked below.

	**Paper**:
	Fagerström, Jon & Schlecht, Sebastian & Välimäki, Vesa. (2021).
	One-to-Many Conversion for Percussive Samples. doi.org/10.23919/DAFx51585.2021.9768256.
**/
class VelvetNoiseVariator extends SourceEffect {

	public final noiseLengthMs: FastFloat;
	public final strength: FastFloat;
	public final decayRate: FastFloat;

	final highpassFilter: Filter;
	final sparseConvolver: SparseConvolver;

	var averageImpulseSpacing: Float;

	/**
		Create a new `VelvetNoiseVariator`.
		@param noiseLengthMs The length of the velvet noise used for convolution, in milliseconds.
		@param numImpulses The amount of impulses in the velvet noise.
		@param decayRate The strength of the exponential decay of the velvet noise impulses.
		@param lowShelfCutoff The cutoff frequency for the integrated high-pass filter.
		@param strength The strength/influence of this effect. Think of this as a dry/wet control.
	**/
	public function new(noiseLengthMs: FastFloat, numImpulses: Int, decayRate: FastFloat, lowShelfCutoff: Hertz, strength: FastFloat) {
		this.noiseLengthMs = noiseLengthMs;
		final noiseLengthSamples = msToSamples(Aura.sampleRate, noiseLengthMs);
		this.sparseConvolver = new SparseConvolver(numImpulses, noiseLengthSamples);
		this.averageImpulseSpacing = maxF(1.0, noiseLengthSamples / numImpulses);

		this.highpassFilter = new Filter(HighPass);
		highpassFilter.setCutoffFreq(lowShelfCutoff, All);

		this.applyOnReplay.store(true);
		this.decayRate = decayRate;
		this.strength = strength;
	}

	public static function fillVelvetNoiseSparse(impulseBuffer: SparseImpulseBuffer, averageImpulseSpacing: Float, decayRate: FastFloat) {
		var nextGridPosPrecise = 0.0;
		var nextGridPosRounded = 0;
		var nextImpulsePos = 0;

		// Attenuate consecutive pulses
		final expFactor = Math.pow(E_INV, decayRate); // e^(-decayRate) == 1/e^decayRate == (1/e)^decayRate
		var exponentialDecayFactor = 1.0;

		for (i in 0...impulseBuffer.length) {
			final currentGridPosRounded = nextGridPosRounded;

			nextGridPosPrecise += averageImpulseSpacing;
			nextGridPosRounded = Math.round(nextGridPosPrecise);

			nextImpulsePos = currentGridPosRounded + Std.random(nextGridPosRounded - currentGridPosRounded);

			impulseBuffer.setImpulsePos(i, nextImpulsePos);
			impulseBuffer.setImpulseMagnitude(i, (Math.random() < 0.5 ? -1.0 : 1.0) * exponentialDecayFactor);
			exponentialDecayFactor *= expFactor; // e^(-decayRate*i) == e^(-decayRate)^i
		}
	}

	function calculateRequiredChannelLength(srcChannelLength: Int): Int {
		return srcChannelLength + sparseConvolver.getMaxNumImpulseResponseSamples() - 1;
	}

	@:access(aura.dsp.SparseConvolver)
	function process(srcBuffer: AudioBuffer, srcChannelLength: Int, dstBuffer: AudioBuffer): Int {
		final requiredLength = calculateRequiredChannelLength(srcChannelLength);

		// Copy and pad data
		for (c in 0...srcBuffer.numChannels) {
			final srcChannelView = srcBuffer.getChannelView(c);
			final dstChannelView = dstBuffer.getChannelView(c);

			for (i in 0...srcChannelLength) {
				dstChannelView[i] = srcChannelView[i];
			}

			// Pad with zeroes to convolve without overlapping
			for (i in srcChannelLength...requiredLength) {
				dstChannelView[i] = 0.0;
			}
		}

		fillVelvetNoiseSparse(sparseConvolver.impulseBuffer, averageImpulseSpacing, decayRate);
		highpassFilter.process(dstBuffer);
		sparseConvolver.process(dstBuffer);

		for (c in 0...srcBuffer.numChannels) {
			final srcChannelView = srcBuffer.getChannelView(c);
			final dstChannelView = dstBuffer.getChannelView(c);

			for (i in 0...srcChannelLength) {
				dstChannelView[i] = dstChannelView[i] * strength + srcChannelView[i];
			}

			for (i in srcChannelLength...requiredLength) {
				dstChannelView[i] = dstChannelView[i] * strength;
			}
		}

		return requiredLength;
	}
}

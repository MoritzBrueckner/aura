package aura.types;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.Types.AtomicInt;

// TODO: Make generic in some way
@:nullSafety(StrictThreaded)
class SwapBuffer {
	static final ROW_COUNT = 2;

	public final length: Int;

	// https://www.usenix.org/legacy/publications/library/proceedings/usenix02/full_papers/huang/huang_html/node8.html
	public final data: Vector<Vector<Float32Array>>;
	final readerCount: Vector<AtomicInt>;
	final newerBuf: Vector<AtomicInt>;

	var latestWriteRow: AtomicInt = 0;
	var curWriteBufIdx: AtomicInt = 0;
	var curWriteRowIdx: AtomicInt = 0;
	var curReadRowIdx: AtomicInt = 0;

	public function new(length: Int) {
		this.length = length;

		this.data = new Vector(ROW_COUNT);
		for (i in 0...ROW_COUNT) {
			data[i] = new Vector(ROW_COUNT);
			for (j in 0...ROW_COUNT) {
				data[i][j] = new Float32Array(length);
			}
		}

		this.readerCount = new Vector(ROW_COUNT);
		for (i in 0...ROW_COUNT) {
			readerCount[i] = 0;
		}

		this.newerBuf = new Vector(ROW_COUNT);
		for (i in 0...ROW_COUNT) {
			newerBuf[i] = 0;
		}
	}

	public inline function beginRead() {
		curReadRowIdx = latestWriteRow;
		#if cpp
			readerCount[curReadRowIdx] = AtomicInt.atomicInc(readerCount[curReadRowIdx].toPtr());
		#else
			readerCount[curReadRowIdx]++;
		#end
	}

	public inline function endRead() {
		#if cpp
			readerCount[curReadRowIdx] = AtomicInt.atomicDec(readerCount[curReadRowIdx].toPtr());
		#else
			readerCount[curReadRowIdx]--;
		#end
	}

	public inline function read(dst: Float32Array, dstStart: Int, srcStart: Int, length: Int) {
		final bufIdx = newerBuf[curReadRowIdx];
		for (i in 0...length) {
			dst[dstStart + i] = data[curReadRowIdx][bufIdx][srcStart + i];
		}
	}

	public inline function beginWrite() {
		for (i in 0...ROW_COUNT) {
			if (readerCount[i] == 0) {
				curWriteRowIdx = i;
				break;
			}
		}

		// Select the least current row buffer
		curWriteBufIdx = 1 - newerBuf[curWriteRowIdx];
	}

	public inline function endWrite() {
		newerBuf[curWriteRowIdx] = curWriteBufIdx;
		latestWriteRow = curWriteRowIdx;
	}

	public inline function write(src: Float32Array, srcStart: Int, dstStart: Int, length: Int = -1) {
		if (length == -1) {
			length = src.length - srcStart;
		}
		for (i in srcStart...srcStart + length) {
			data[curWriteRowIdx][curWriteBufIdx][dstStart + i] = src[i]; // TODO: Investigate possible memory leaks through allocating
		}
	}

	public inline function writeVecF(src: Vector<Float>, srcStart: Int, dstStart: Int, length: Int = -1) {
		if (length == -1) {
			length = src.length - srcStart;
		}
		for (i in srcStart...srcStart + length) {
			data[curWriteRowIdx][curWriteBufIdx][dstStart + i] = src[i];
		}
	}

	public inline function writeZero(dstStart: Int, dstEnd: Int) {
		for (i in dstStart...dstEnd) {
			data[curWriteRowIdx][curWriteBufIdx][i] = 0;
		}
	}
}

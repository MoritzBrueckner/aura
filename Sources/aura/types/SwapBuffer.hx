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

	var latestWriteRow: AtomicInt = new AtomicInt(0);
	var curWriteBufIdx: AtomicInt = new AtomicInt(0);
	var curWriteRowIdx: AtomicInt = new AtomicInt(0);
	var curReadRowIdx: AtomicInt = new AtomicInt(0);

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
			readerCount[i].store(0);
		}

		this.newerBuf = new Vector(ROW_COUNT);
		for (i in 0...ROW_COUNT) {
			newerBuf[i].store(0);
		}
	}

	public inline function beginRead() {
		curReadRowIdx = latestWriteRow;
		#if cpp
			readerCount[curReadRowIdx] = AtomicInt.atomicInc(readerCount[curReadRowIdx].toPtr());
		#else
			// Put array access in parentheses to make compiler happy in case of HL: "Don't know how to cast i32 to array"
			(readerCount[curReadRowIdx.load()])++;
		#end
	}

	public inline function endRead() {
		#if cpp
			readerCount[curReadRowIdx] = AtomicInt.atomicDec(readerCount[curReadRowIdx].toPtr());
		#else
			(readerCount[curReadRowIdx.load()])--;
		#end
	}

	public inline function read(dst: Float32Array, dstStart: Int, srcStart: Int, length: Int) {
		final bufIdx = newerBuf[curReadRowIdx.load()];
		for (i in 0...length) {
			dst[dstStart + i] = data[curReadRowIdx.load()][bufIdx.load()][srcStart + i];
		}
	}

	public inline function beginWrite() {
		for (i in 0...ROW_COUNT) {
			if (readerCount[i].load() == 0) {
				curWriteRowIdx.store(i);
				break;
			}
		}

		// Select the least current row buffer
		curWriteBufIdx.store(1 - newerBuf[curWriteRowIdx.load()].load());
	}

	public inline function endWrite() {
		newerBuf[curWriteRowIdx.load()].store(curWriteBufIdx.load());
		latestWriteRow = curWriteRowIdx;
	}

	public inline function write(src: Float32Array, srcStart: Int, dstStart: Int, length: Int = -1) {
		if (length == -1) {
			length = src.length - srcStart;
		}
		for (i in srcStart...srcStart + length) {
			data[curWriteRowIdx.load()][curWriteBufIdx.load()][dstStart + i] = src[i]; // TODO: Investigate possible memory leaks through allocating
		}
	}

	public inline function writeVecF(src: Vector<Float>, srcStart: Int, dstStart: Int, length: Int = -1) {
		if (length == -1) {
			length = src.length - srcStart;
		}
		for (i in srcStart...srcStart + length) {
			data[curWriteRowIdx.load()][curWriteBufIdx.load()][dstStart + i] = src[i];
		}
	}

	public inline function writeZero(dstStart: Int, dstEnd: Int) {
		for (i in dstStart...dstEnd) {
			data[curWriteRowIdx.load()][curWriteBufIdx.load()][i] = 0;
		}
	}
}

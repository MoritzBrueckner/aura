package auratests.threading;

import aura.threading.Fifo;

import utest.Assert;

class TestFifo extends utest.Test {
	var fifo: Fifo<Int>;

	function setup() {
		fifo = new Fifo();
	}

	function test_popFromEmptyFifoReturnsNull() {
		Assert.isNull(fifo.tryPop());
	}

	function test_fifoIsEmptyAfterPoppingLastItem() {
		fifo.add(0);
		fifo.add(1);

		fifo.tryPop();
		fifo.tryPop();
		Assert.isNull(fifo.tryPop());
	}

	function test_ItemsArePoppedInOrderTheyAreAdded() {
		fifo.add(0);
		fifo.add(1);

		Assert.equals(0, fifo.tryPop());
		Assert.equals(1, fifo.tryPop());
	}
}

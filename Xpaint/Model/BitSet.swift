struct BitSet: Equatable, Sequence {
	fileprivate static let width = UInt8.bitWidth

	private(set) var storage: [UInt8]
	private(set) var count: Int

	var indices: Range<Int> { 0..<count }
	var isEmpty: Bool { !storage.contains(where: { $0 != 0 }) }

	init(count: Int, filled: Bool = false) {
		self.count = Swift.max(0, count)
		storage = .init(
			repeating: filled ? .max : 0,
			count: (self.count + Self.width - 1) / Self.width
		)
		clearUnusedBits()
	}

	subscript(_ index: Int) -> Bool {
		get {
			guard indices.contains(index) else { return false }
			return storage[index / Self.width] & (1 << (index % Self.width)) != 0
		}
		set {
			guard indices.contains(index) else { return }
			if newValue {
				storage[index / Self.width] |= 1 << (index % Self.width)
			} else {
				storage[index / Self.width] &= ~(1 << (index % Self.width))
			}
		}
	}

	mutating func formUnion(_ other: BitSet) {
		for index in 0..<Swift.min(storage.count, other.storage.count) {
			storage[index] |= other.storage[index]
		}
		clearUnusedBits()
	}

	func union(_ other: BitSet) -> BitSet {
		modifying(self) { $0.formUnion(other) }
	}

	mutating func subtract(_ other: BitSet) {
		for index in 0..<Swift.min(storage.count, other.storage.count) {
			storage[index] &= ~other.storage[index]
		}
		clearUnusedBits()
	}

	func subtracting(_ other: BitSet) -> BitSet {
		modifying(self) { $0.subtract(other) }
	}

	func makeIterator() -> Iterator {
		Iterator(bits: self)
	}

	struct Iterator: IteratorProtocol {
		private let bits: BitSet
		private var index = 0

		fileprivate init(bits: BitSet) {
			self.bits = bits
		}

		mutating func next() -> Int? {
			while index < bits.count {
				let word = index / BitSet.width
				guard bits.storage[word] != 0 else {
					index = (word + 1) * BitSet.width
					continue
				}
				defer { index += 1 }
				if bits[index] { return index }
			}
			return nil
		}
	}

	private mutating func clearUnusedBits() {
		guard let last = storage.indices.last else { return }
		let used = count % Self.width
		guard used != 0 else { return }
		storage[last] &= UInt8.max >> (Self.width - used)
	}
}

extension BitSet {

	/// Bits set for every pixel inside the rectangle spanned by `start` and `end`, clipped to `size`.
	static func rectangle(size: FilmSize, from start: PxL, to end: PxL) -> BitSet {
		var result = BitSet(count: size.count)
		let minX = Swift.max(0, Swift.min(start.x, end.x))
		let maxX = Swift.min(size.width - 1, Swift.max(start.x, end.x))
		let minY = Swift.max(0, Swift.min(start.y, end.y))
		let maxY = Swift.min(size.height - 1, Swift.max(start.y, end.y))

		guard minX <= maxX, minY <= maxY else { return result }
		for y in minY...maxY {
			for x in minX...maxX {
				if let index = size.index(at: PxL(x: x, y: y, z: 0)) {
					result[index] = true
				}
			}
		}
		return result
	}
}

extension Optional where Wrapped == BitSet {

	/// Selection semantics: the absence of a selection means the whole layer is writable.
	func allows(_ index: Int) -> Bool {
		self?[index] ?? true
	}
}

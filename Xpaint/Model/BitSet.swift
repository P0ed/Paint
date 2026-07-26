import Foundation

struct BitSet: Equatable, Sequence {
	private static let width = UInt8.bitWidth

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

	mutating func fill(_ value: Bool = true) {
		storage = .init(repeating: value ? .max : 0, count: storage.count)
		clearUnusedBits()
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

func rectangularMask(size: FilmSize, from start: PxL, to end: PxL) -> BitSet {
	var result = BitSet(count: size.count)
	let minX = max(0, min(start.x, end.x))
	let maxX = min(size.width - 1, max(start.x, end.x))
	let minY = max(0, min(start.y, end.y))
	let maxY = min(size.height - 1, max(start.y, end.y))

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

func rasterizedLine(from start: PxL, to end: PxL) -> [PxL] {
	var result: [PxL] = []
	var x = start.x
	var y = start.y
	let dx = abs(end.x - start.x)
	let sx = start.x < end.x ? 1 : -1
	let dy = -abs(end.y - start.y)
	let sy = start.y < end.y ? 1 : -1
	var error = dx + dy

	while true {
		result.append(PxL(x: x, y: y, z: start.z))
		if x == end.x, y == end.y { break }
		let doubled = 2 * error
		if doubled >= dy {
			error += dy
			x += sx
		}
		if doubled <= dx {
			error += dx
			y += sy
		}
	}
	return result
}

func snappedEndpoint(from start: PxL, to end: PxL) -> PxL {
	let dx = end.x - start.x
	let dy = end.y - start.y
	guard dx != 0 || dy != 0 else { return end }

	let bases = [(1, 0), (2, 1), (1, 1), (1, 2), (0, 1)]
	var best = (x: 1, y: 0)
	var bestScore = -Double.infinity

	for base in bases {
		let xs = base.0 == 0 ? [0] : [-base.0, base.0]
		let ys = base.1 == 0 ? [0] : [-base.1, base.1]
		for x in xs {
			for y in ys {
				let dot = Double(dx * x + dy * y)
				guard dot > 0 else { continue }
				let deltaLength = Double(dx * dx + dy * dy)
				let directionLength = Double(x * x + y * y)
				let score = dot / Foundation.sqrt(deltaLength * directionLength)
				if score > bestScore {
					bestScore = score
					best = (x, y)
				}
			}
		}
	}

	let lengthSquared = best.x * best.x + best.y * best.y
	let multiple = max(1, Int((Double(dx * best.x + dy * best.y) / Double(lengthSquared)).rounded()))
	var snappedX = best.x * multiple
	var snappedY = best.y * multiple
	if abs(best.x) == 2 {
		snappedX += best.x.signum()
	}
	if abs(best.y) == 2 {
		snappedY += best.y.signum()
	}
	return PxL(
		x: start.x + snappedX,
		y: start.y + snappedY,
		z: start.z
	)
}

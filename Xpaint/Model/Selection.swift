struct Selection: Equatable {
	var bits: BitSet
	var active: Bool
}

extension Selection {

	static let none = Selection(bits: BitSet(count: 0), active: false)

	init(_ bits: BitSet) {
		self.init(bits: bits, active: true)
	}

	var mask: BitSet? { active ? bits : nil }

	func allows(_ index: Int) -> Bool {
		mask.allows(index)
	}

	mutating func toggle() {
		active.toggle()
	}

	mutating func invert(size: FilmSize) {
		let all = BitSet(count: size.count, filled: true)
		self = Selection(all.subtracting(mask ?? all))
	}

	mutating func move(size: FilmSize, dx: Int, dy: Int) {
		guard active else { return }
		bits = bits.moved(size: size, dx: dx, dy: dy)
	}
}

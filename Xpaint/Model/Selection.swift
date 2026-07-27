/// A committed mask together with whether it currently applies.
/// Switching it off is not the same as forgetting it: the bits survive, so the toggle can bring
/// the exact same mask back.
struct Selection: Equatable {
	var bits: BitSet
	var active: Bool
}

extension Selection {

	/// Nothing masked at all, which means the whole layer is writable.
	static let none = Selection(bits: BitSet(count: 0), active: false)

	/// A freshly committed mask, switched on.
	init(_ bits: BitSet) {
		self.init(bits: bits, active: true)
	}

	/// The mask to clip against, or `nil` while the selection is off: an inactive selection reads
	/// exactly like an absent one, so the whole layer stays live.
	var mask: BitSet? { active ? bits : nil }

	func allows(_ index: Int) -> Bool {
		mask.allows(index)
	}

	mutating func toggle() {
		active.toggle()
	}

	/// Swaps the selected pixels for the unselected ones.
	/// An inactive selection covers the whole layer, so inverting it selects nothing.
	mutating func invert(size: FilmSize) {
		let all = BitSet(count: size.count, filled: true)
		self = Selection(all.subtracting(mask ?? all))
	}

	/// Slides the mask, leaving the pixels under it alone. Off means there is nothing to slide.
	mutating func move(size: FilmSize, dx: Int, dy: Int) {
		guard active else { return }
		bits = bits.moved(size: size, dx: dx, dy: dy)
	}
}

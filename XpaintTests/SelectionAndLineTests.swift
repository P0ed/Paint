import XCTest
import SwiftUI
@testable import Xpaint

final class BitSetAndGeometryTests: XCTestCase {
	func testBitSetAlgebraIterationAndBoundsSafety() {
		var lhs = BitSet(count: 10)
		lhs[-1] = true
		lhs[10] = true
		lhs[1] = true
		lhs[8] = true
		XCTAssertEqual(Array(lhs), [1, 8])

		var rhs = BitSet(count: 10)
		rhs[2] = true
		rhs[8] = true
		XCTAssertEqual(Array(lhs.union(rhs)), [1, 2, 8])
		XCTAssertEqual(Array(lhs.subtracting(rhs)), [1])

		var filled = BitSet(count: 10)
		filled.fill()
		XCTAssertEqual(Array(filled), Array(0..<10))
		filled.fill(false)
		XCTAssertTrue(filled.isEmpty)
		XCTAssertEqual(filled, BitSet(count: 10))
	}

	func testRectangleIsInclusiveAndClampedWithoutSelectingOutsideIntersection() {
		let size = FilmSize(width: 4, height: 3, frames: 1)
		let mask = rectangularMask(
			size: size,
			from: PxL(x: -2, y: 1, z: 0),
			to: PxL(x: 2, y: 9, z: 0)
		)
		let points = Set(mask.map { size.pxl(at: $0).xy })
		let expected = Set((1...2).flatMap { y in
			(0...2).map { x in PxL(x: x, y: y, z: 0) }
		})
		XCTAssertEqual(points, expected)
		XCTAssertTrue(rectangularMask(
			size: size,
			from: PxL(x: -3, y: 0, z: 0),
			to: PxL(x: -1, y: 2, z: 0)
		).isEmpty)
	}

	func testBresenhamCoversEveryOctantAndReverses() {
		let origin = PxL(x: 8, y: 8, z: 2)
		let deltas = [(5, 2), (2, 5), (-2, 5), (-5, 2), (-5, -2), (-2, -5), (2, -5), (5, -2)]
		for delta in deltas {
			let end = PxL(x: origin.x + delta.0, y: origin.y + delta.1, z: 2)
			let forward = rasterizedLine(from: origin, to: end)
			let reverse = rasterizedLine(from: end, to: origin)
			XCTAssertEqual(forward.first, origin)
			XCTAssertEqual(forward.last, end)
			XCTAssertEqual(forward.count, max(abs(delta.0), abs(delta.1)) + 1)
			XCTAssertEqual(Set(forward), Set(reverse))
			for pair in zip(forward, forward.dropFirst()) {
				XCTAssertLessThanOrEqual(abs(pair.0.x - pair.1.x), 1)
				XCTAssertLessThanOrEqual(abs(pair.0.y - pair.1.y), 1)
			}
		}
		XCTAssertEqual(rasterizedLine(from: origin, to: origin), [origin])
	}

	func testSnappingPreservesEverySupportedSlopeAndSign() {
		let start = PxL(x: 20, y: 20, z: 3)
		let bases = [(1, 0), (2, 1), (1, 1), (1, 2), (0, 1)]
		for base in bases {
			let xs = base.0 == 0 ? [0] : [-base.0, base.0]
			let ys = base.1 == 0 ? [0] : [-base.1, base.1]
			for x in xs {
				for y in ys {
					let end = PxL(x: start.x + 3 * x, y: start.y + 3 * y, z: 3)
					XCTAssertEqual(snappedEndpoint(from: start, to: end), end)
				}
			}
		}
	}
}

final class InteractionStateTests: XCTestCase {
	private let size = FilmSize(width: 4, height: 4, frames: 1)

	func testAbsentAndEmptySelectionsDiffer() {
		var state = EditorState()
		XCTAssertTrue(state.allows(0))
		state.selection = BitSet(count: size.count)
		XCTAssertFalse(state.allows(0))
	}

	func testModifierPrecedenceAndClickRules() {
		XCTAssertEqual(SelectionMode(shift: true, option: true), .subtract)
		var state = EditorState()
		state.selectAll(count: size.count)
		let original = state.selection

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .union)
		state.endSelection(size: size)
		XCTAssertEqual(state.selection, original)

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .subtract)
		state.endSelection(size: size)
		XCTAssertEqual(state.selection, original)

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .replace)
		state.endSelection(size: size)
		XCTAssertNil(state.selection)
	}

	func testSelectionUnionAndSubtractionUseStartingMask() {
		var state = EditorState()
		state.beginSelection(at: PxL(x: 0, y: 0, z: 0), mode: .replace)
		state.updateSelection(to: PxL(x: 1, y: 1, z: 0))
		state.endSelection(size: size)
		XCTAssertEqual(Array(state.selection!), [8, 9, 12, 13])

		state.beginSelection(at: PxL(x: 2, y: 0, z: 0), mode: .union)
		state.updateSelection(to: PxL(x: 2, y: 1, z: 0))
		XCTAssertEqual(Array(state.selectionPreview(size: size)!), [8, 9, 10, 12, 13, 14])
		state.endSelection(size: size)

		state.beginSelection(at: PxL(x: 1, y: 0, z: 0), mode: .subtract)
		state.updateSelection(to: PxL(x: 2, y: 0, z: 0))
		state.endSelection(size: size)
		XCTAssertEqual(Array(state.selection!), [8, 9, 10, 12])
	}

	func testDragAndClickClickLineTransitionsAndCancellation() {
		var state = EditorState()
		state.tool = .line
		let a = PxL(x: 0, y: 0, z: 0)
		let b = PxL(x: 3, y: 2, z: 0)

		state.beginLineGesture(at: a)
		state.updateLine(to: a, snapped: false)
		XCTAssertNil(state.endLineGesture())
		XCTAssertEqual(state.lineSession?.phase, .pending)

		state.hoverLine(to: b, snapped: false)
		XCTAssertEqual(state.lineSession?.end, b)
		state.beginLineGesture(at: b)
		state.updateLine(to: b, snapped: false)
		let committed = state.endLineGesture()
		XCTAssertEqual(committed?.0, a)
		XCTAssertEqual(committed?.1, b)
		XCTAssertNil(state.lineSession)

		state.beginLineGesture(at: a)
		state.updateLine(to: b, snapped: false)
		XCTAssertEqual(state.endLineGesture()?.1, b)

		state.beginLineGesture(at: a)
		state.updateLine(to: a, snapped: false)
		_ = state.endLineGesture()
		state.tool = .pencil
		XCTAssertNil(state.lineSession)

		state.selection = BitSet(count: size.count, filled: true)
		state.lineSession = LineSession(start: a, end: b, phase: .pending)
		state.resetTransientInteractions()
		XCTAssertNil(state.selection)
		XCTAssertNil(state.lineSession)
	}
}

@MainActor
final class SelectionClippingTests: XCTestCase {
	private let red = Px(rgb: 0x0000FF)
	private let green = Px(rgb: 0x00FF00)
	private let blue = Px(rgb: 0xFF0000)

	func testDrawingLineReplaceAndEmptySelectionClipping() {
		var film = Film(width: 3, height: 1, frames: 1, color: .white)
		let empty = BitSet(count: 3)
		film.drawPixel(red, at: PxL(x: 0, y: 0, z: 0), selection: empty)
		XCTAssertEqual(film.pxs, [.white, .white, .white])

		var middle = BitSet(count: 3)
		middle[1] = true
		film.drawLine(
			from: PxL(x: 0, y: 0, z: 0),
			to: PxL(x: 2, y: 0, z: 0),
			primary: red,
			secondary: red,
			selection: middle
		)
		XCTAssertEqual(film.pxs, [.white, red, .white])

		film.replaceColor(
			at: PxL(x: 0, y: 0, z: 0),
			primary: blue,
			secondary: blue,
			selection: middle
		)
		XCTAssertEqual(film.pxs, [.white, red, .white])
	}

	func testFloodFillCannotStartOrTraverseOutsideSelection() {
		var film = Film(width: 3, height: 1, frames: 1, color: .white)
		var disconnected = BitSet(count: 3)
		disconnected[0] = true
		disconnected[2] = true
		film.floodFill(
			at: PxL(x: 0, y: 0, z: 0),
			primary: red,
			secondary: red,
			selection: disconnected
		)
		XCTAssertEqual(film.pxs, [red, .white, .white])

		film.floodFill(
			at: PxL(x: 1, y: 0, z: 0),
			primary: blue,
			secondary: blue,
			selection: disconnected
		)
		XCTAssertEqual(film.pxs, [red, .white, .white])
	}

	func testCutPasteMovementAndWholeLayerMutationAreDestinationClipped() {
		let harness = Harness(film: Film(width: 3, height: 1, frames: 1, color: .clear))
		harness.film.pxs = [red, green, blue]
		var middle = BitSet(count: 3)
		middle[1] = true
		harness.state.selection = middle

		harness.operations.cut()
		XCTAssertEqual(harness.film.pxs, [red, .clear, blue])
		XCTAssertEqual(Array(harness.global.pxs.prefix(3)), [red, green, blue])

		harness.film.pxs = [.clear, .clear, .clear]
		harness.operations.paste()
		XCTAssertEqual(harness.film.pxs, [.clear, green, .clear])

		harness.film.pxs = [red, green, blue]
		harness.operations.move(dx: 1)
		XCTAssertEqual(harness.film.pxs, [red, red, blue])

		harness.operations.wipeLayer()
		XCTAssertEqual(harness.film.pxs, [red, .clear, blue])
	}

	func testColorOperationsAndShaderAreClipped() {
		let harness = Harness(film: Film(width: 3, height: 1, frames: 1, color: .clear))
		let original = Px(alpha: 255, red: 100, green: 50, blue: 20)
		harness.film.pxs = [original, original, original]
		var middle = BitSet(count: 3)
		middle[1] = true
		harness.state.selection = middle

		harness.operations.shiftRight()
		XCTAssertEqual(harness.film.pxs[0], original)
		XCTAssertEqual(harness.film.pxs[1], Px(alpha: 255, red: 50, green: 25, blue: 10))
		XCTAssertEqual(harness.film.pxs[2], original)

		harness.operations.makeMonochrome()
		XCTAssertEqual(harness.film.pxs[0], original)
		XCTAssertEqual(harness.film.pxs[1], Px(alpha: 255, red: 28, green: 28, blue: 28))
		XCTAssertEqual(harness.film.pxs[2], original)

		harness.shader.function = "(r, g, b, a, x, y) => [1, 2, 3, 255]"
		harness.operations.applyShader()
		XCTAssertEqual(harness.film.pxs[0], original)
		XCTAssertEqual(harness.film.pxs[1], Px(alpha: 255, red: 1, green: 2, blue: 3))
		XCTAssertEqual(harness.film.pxs[2], original)
	}
}

@MainActor
private final class Harness {
	var state = EditorState()
	var palette = Palette.warm
	var shader = Shader.default
	var film: Film
	var global: Film

	init(film: Film) {
		self.film = film
		global = Film(width: film.size.width, height: film.size.height, frames: 1, color: .clear)
	}

	var operations: Operations {
		Operations(
			state: Binding(get: { self.state }, set: { self.state = $0 }),
			palette: Binding(get: { self.palette }, set: { self.palette = $0 }),
			shader: Binding(get: { self.shader }, set: { self.shader = $0 }),
			film: Binding(get: { self.film }, set: { self.film = $0 }),
			global: Binding(get: { self.global }, set: { self.global = $0 })
		)
	}
}

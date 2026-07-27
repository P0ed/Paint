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

		let filled = BitSet(count: 10, filled: true)
		XCTAssertEqual(Array(filled), Array(0..<10))
		XCTAssertTrue(BitSet(count: 10).isEmpty)
		XCTAssertEqual(filled.subtracting(filled), BitSet(count: 10))
	}

	func testRectangleIsInclusiveAndClampedWithoutSelectingOutsideIntersection() {
		let size = FilmSize(width: 4, height: 3, frames: 1)
		let mask = BitSet.rectangle(
			size: size,
			from: PxL(x: -2, y: 1, z: 0),
			to: PxL(x: 2, y: 9, z: 0)
		)
		let points = Set(mask.map { size.pxl(at: $0).xy })
		let expected = Set((1...2).flatMap { y in
			(0...2).map { x in PxL(x: x, y: y, z: 0) }
		})
		XCTAssertEqual(points, expected)
		XCTAssertTrue(BitSet.rectangle(
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
			let forward = [PxL].rasterizedLine(from: origin, to: end)
			let reverse = [PxL].rasterizedLine(from: end, to: origin)
			XCTAssertEqual(forward.first, origin)
			XCTAssertEqual(forward.last, end)
			XCTAssertEqual(forward.count, max(abs(delta.0), abs(delta.1)) + 1)
			XCTAssertEqual(Set(forward), Set(reverse))
			for pair in zip(forward, forward.dropFirst()) {
				XCTAssertLessThanOrEqual(abs(pair.0.x - pair.1.x), 1)
				XCTAssertLessThanOrEqual(abs(pair.0.y - pair.1.y), 1)
			}
		}
		XCTAssertEqual([PxL].rasterizedLine(from: origin, to: origin), [origin])
	}

	func testSnappingPreservesEverySupportedDirectionAndSign() {
		let start = PxL(x: 20, y: 20, z: 3)
		let bases = [(1, 0), (2, 1), (1, 1), (1, 2), (0, 1)]
		for base in bases {
			let xs = base.0 == 0 ? [0] : [-base.0, base.0]
			let ys = base.1 == 0 ? [0] : [-base.1, base.1]
			for x in xs {
				for y in ys {
					let end = PxL(x: start.x + 3 * x, y: start.y + 3 * y, z: 3)
					let extraX = abs(x) == 2 ? x.signum() : 0
					let extraY = abs(y) == 2 ? y.signum() : 0
					XCTAssertEqual(
						start.snappedEndpoint(to: end),
						PxL(x: end.x + extraX, y: end.y + extraY, z: end.z)
					)
				}
			}
		}
	}

	func testTwoToOneSnappedLinesBeginAndEndWithTwoPixelsOnTheMajorAxis() {
		let start = PxL(x: 0, y: 0, z: 3)
		let shallowEnd = start.snappedEndpoint(to: PxL(x: 4, y: 2, z: 3))
		let shallow = [PxL].rasterizedLine(from: start, to: shallowEnd)
		XCTAssertEqual(
			Array(shallow.prefix(2)),
			[PxL(x: 0, y: 0, z: 3), PxL(x: 1, y: 0, z: 3)]
		)
		XCTAssertEqual(
			Array(shallow.suffix(2)),
			[PxL(x: 4, y: 2, z: 3), PxL(x: 5, y: 2, z: 3)]
		)

		let steepEnd = start.snappedEndpoint(to: PxL(x: 2, y: 4, z: 3))
		let steep = [PxL].rasterizedLine(from: start, to: steepEnd)
		XCTAssertEqual(
			Array(steep.prefix(2)),
			[PxL(x: 0, y: 0, z: 3), PxL(x: 0, y: 1, z: 3)]
		)
		XCTAssertEqual(
			Array(steep.suffix(2)),
			[PxL(x: 2, y: 4, z: 3), PxL(x: 2, y: 5, z: 3)]
		)
	}
}

final class InteractionStateTests: XCTestCase {
	private let size = FilmSize(width: 4, height: 4, frames: 1)

	func testAbsentAndEmptySelectionsDiffer() {
		var state = EditorState()
		XCTAssertTrue(state.selection.allows(0))
		state.selection = BitSet(count: size.count)
		XCTAssertFalse(state.selection.allows(0))
	}

	func testModifierPrecedenceAndClickRules() {
		XCTAssertEqual(SelectionMode(shift: true, option: true), .subtract)
		var state = EditorState()
		state.selection = BitSet(count: size.count, filled: true)
		let original = state.selection

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .union)
		state.endSelection()
		XCTAssertEqual(state.selection, original)

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .subtract)
		state.endSelection()
		XCTAssertEqual(state.selection, original)

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .replace)
		state.endSelection()
		XCTAssertNil(state.selection)
	}

	func testSelectionUnionAndSubtractionUseStartingMask() {
		var state = EditorState()
		state.beginSelection(at: PxL(x: 0, y: 0, z: 0), mode: .replace)
		state.updateSelection(to: PxL(x: 1, y: 1, z: 0), size: size)
		state.endSelection()
		XCTAssertEqual(Array(state.selection!), [8, 9, 12, 13])

		state.beginSelection(at: PxL(x: 2, y: 0, z: 0), mode: .union)
		state.updateSelection(to: PxL(x: 2, y: 1, z: 0), size: size)
		XCTAssertEqual(Array(state.selectionPreview!), [8, 9, 10, 12, 13, 14])
		state.endSelection()

		state.beginSelection(at: PxL(x: 1, y: 0, z: 0), mode: .subtract)
		state.updateSelection(to: PxL(x: 2, y: 0, z: 0), size: size)
		state.endSelection()
		XCTAssertEqual(Array(state.selection!), [8, 9, 10, 12])
	}

	func testSubtractingWithoutASelectionExcludesTheRectangleFromTheWholeLayer() {
		var state = EditorState()
		state.beginSelection(at: PxL(x: 0, y: 0, z: 0), mode: .subtract)
		state.updateSelection(to: PxL(x: 1, y: 1, z: 0), size: size)
		state.endSelection()
		XCTAssertEqual(
			Array(state.selection!),
			Array(0..<size.count).filter { ![8, 9, 12, 13].contains($0) }
		)
	}

	func testDragPreviewIsCachedUntilTheDragReachesAnotherPixel() {
		var state = EditorState()
		state.beginSelection(at: PxL(x: 0, y: 0, z: 0), mode: .replace)
		XCTAssertNil(state.selectionPreview)

		state.updateSelection(to: PxL(x: 1, y: 1, z: 0), size: size)
		let preview = state.selectionSession?.preview
		XCTAssertEqual(Array(preview!), [8, 9, 12, 13])

		// A move within the same pixel must not rebuild the mask.
		state.selection = BitSet(count: size.count)
		state.updateSelection(to: PxL(x: 1, y: 1, z: 1), size: size)
		XCTAssertEqual(state.selectionSession?.preview, preview)
	}

	func testMovingTheSelectionSlidesTheMaskAndClipsAtTheEdge() {
		var state = EditorState()
		state.moveSelection(dx: 1, size: size)
		XCTAssertNil(state.selection)

		var mask = BitSet(count: size.count)
		mask[0] = true
		mask[3] = true
		state.selection = mask

		// Index 3 sits in the rightmost column, so it falls off; index 0 shifts one column over.
		state.moveSelection(dx: 1, size: size)
		XCTAssertEqual(Array(state.selection!), [1])

		// A positive `dy` travels with the down arrow, matching how `move` shifts pixels.
		state.moveSelection(dy: 1, size: size)
		XCTAssertEqual(Array(state.selection!), [5])
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
		state.beginSelection(at: a, mode: .replace)

		// What Escape does: the gestures go, the committed selection stays.
		state.cancelSessions()
		XCTAssertEqual(state.selection, BitSet(count: size.count, filled: true))
		XCTAssertNil(state.lineSession)
		XCTAssertNil(state.selectionSession)

		state.resetTransientInteractions()
		XCTAssertNil(state.selection)
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
		// Green has nowhere to go and blue is protected by sitting outside the selection.
		XCTAssertEqual(harness.film.pxs, [red, .clear, blue])

		harness.operations.wipeLayer()
		XCTAssertEqual(harness.film.pxs, [red, .clear, blue])

		harness.state.secondaryColor = green
		harness.operations.fillLayer()
		XCTAssertEqual(harness.film.pxs, [red, green, blue])
	}

	func testMovingInsideASelectionShiftsItsContentAndClearsBehindIt() {
		let harness = Harness(film: Film(width: 3, height: 1, frames: 1, color: .clear))
		harness.film.pxs = [red, green, blue]
		var pair = BitSet(count: 3)
		pair[1] = true
		pair[2] = true
		harness.state.selection = pair

		harness.operations.move(dx: 1)
		// Green shifts onto blue, the cell it left clears, and red never takes part.
		XCTAssertEqual(harness.film.pxs, [red, .clear, green])
	}

	func testMovingWithAFillTrailsThatColourBehindTheContent() {
		let harness = Harness(film: Film(width: 3, height: 1, frames: 1, color: .clear))
		harness.film.pxs = [red, green, blue]

		harness.operations.move(dx: 1, fill: green)
		XCTAssertEqual(harness.film.pxs, [green, red, green])

		harness.film.pxs = [red, green, blue]
		var pair = BitSet(count: 3)
		pair[1] = true
		pair[2] = true
		harness.state.selection = pair

		harness.operations.move(dx: 1, fill: red)
		XCTAssertEqual(harness.film.pxs, [red, red, green])
	}

	func testMovingASelectionNeverWrapsAcrossRows() {
		let harness = Harness(film: Film(width: 2, height: 2, frames: 1, color: .clear))
		harness.film.pxs = [red, green, blue, red]
		harness.state.selection = BitSet(count: 4, filled: true)

		harness.operations.move(dx: 1)
		XCTAssertEqual(harness.film.pxs, [.clear, red, .clear, blue])
	}

	func testMoveWithoutASelectionTransformsTheLayerInPlace() {
		let harness = Harness(film: Film(width: 3, height: 1, frames: 2, color: .clear))
		harness.film.pxs = [red, green, blue, red, green, blue]
		harness.state.layer = 1

		harness.operations.move(dx: 1)
		XCTAssertEqual(Array(harness.film.pxs.prefix(3)), [red, green, blue])
		XCTAssertEqual(Array(harness.film.pxs.suffix(3)), [.clear, red, green])
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

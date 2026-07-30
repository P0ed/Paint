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
		state.selection = Selection(BitSet(count: size.count))
		XCTAssertFalse(state.selection.allows(0))
	}

	func testTogglingHidesTheMaskWithoutForgettingIt() {
		var state = EditorState()
		var mask = BitSet(count: size.count)
		mask[5] = true
		state.selection = Selection(mask)

		state.toggleSelection()
		XCTAssertNil(state.selection.mask)
		XCTAssertTrue(state.selection.allows(0))
		XCTAssertEqual(state.selection.bits, mask)

		state.toggleSelection()
		XCTAssertEqual(state.selection.mask, mask)
	}

	func testInvertingSwapsTheSelectedPixelsAndTreatsOffAsTheWholeLayer() {
		var state = EditorState()
		var mask = BitSet(count: size.count)
		mask[5] = true
		state.selection = Selection(mask)

		state.invertSelection(size: size)
		XCTAssertEqual(
			Array(state.selection.bits),
			Array(0..<size.count).filter { $0 != 5 }
		)

		state.selection.active = false
		state.invertSelection(size: size)
		XCTAssertTrue(state.selection.active)
		XCTAssertTrue(state.selection.bits.isEmpty)
	}

	func testModifierPrecedenceAndClickRules() {
		XCTAssertEqual(SelectionMode(shift: true, option: true), .subtract)
		var state = EditorState()
		state.selection = Selection(BitSet(count: size.count, filled: true))
		let original = state.selection

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .union)
		state.endSelection()
		XCTAssertEqual(state.selection, original)

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .subtract)
		state.endSelection()
		XCTAssertEqual(state.selection, original)

		state.beginSelection(at: PxL(x: 1, y: 1, z: 0), mode: .replace)
		state.endSelection()
		XCTAssertNil(state.selection.mask)
		XCTAssertEqual(state.selection.bits, original.bits)
	}

	func testSelectionUnionAndSubtractionUseStartingMask() {
		var state = EditorState()
		state.beginSelection(at: PxL(x: 0, y: 0, z: 0), mode: .replace)
		state.updateSelection(to: PxL(x: 1, y: 1, z: 0), size: size)
		state.endSelection()
		XCTAssertEqual(Array(state.selection.bits), [8, 9, 12, 13])

		state.beginSelection(at: PxL(x: 2, y: 0, z: 0), mode: .union)
		state.updateSelection(to: PxL(x: 2, y: 1, z: 0), size: size)
		XCTAssertEqual(Array(state.selectionPreview!), [8, 9, 10, 12, 13, 14])
		state.endSelection()

		state.beginSelection(at: PxL(x: 1, y: 0, z: 0), mode: .subtract)
		state.updateSelection(to: PxL(x: 2, y: 0, z: 0), size: size)
		state.endSelection()
		XCTAssertEqual(Array(state.selection.bits), [8, 9, 10, 12])
	}

	func testSubtractingWithoutASelectionExcludesTheRectangleFromTheWholeLayer() {
		var state = EditorState()
		state.beginSelection(at: PxL(x: 0, y: 0, z: 0), mode: .subtract)
		state.updateSelection(to: PxL(x: 1, y: 1, z: 0), size: size)
		state.endSelection()
		XCTAssertEqual(
			Array(state.selection.bits),
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

		state.selection = Selection(BitSet(count: size.count))
		state.updateSelection(to: PxL(x: 1, y: 1, z: 1), size: size)
		XCTAssertEqual(state.selectionSession?.preview, preview)
	}

	func testMovingTheSelectionSlidesTheMaskAndClipsAtTheEdge() {
		var state = EditorState()
		state.moveSelection(dx: 1, size: size)
		XCTAssertNil(state.selection.mask)

		var mask = BitSet(count: size.count)
		mask[0] = true
		mask[3] = true
		state.selection = Selection(mask)

		state.moveSelection(dx: 1, size: size)
		XCTAssertEqual(Array(state.selection.bits), [1])

		state.moveSelection(dy: 1, size: size)
		XCTAssertEqual(Array(state.selection.bits), [5])
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

		state.selection = Selection(BitSet(count: size.count, filled: true))
		state.lineSession = LineSession(start: a, end: b, phase: .pending)
		state.beginSelection(at: a, mode: .replace)

		state.cancelSessions()
		XCTAssertEqual(state.selection, Selection(BitSet(count: size.count, filled: true)))
		XCTAssertNil(state.lineSession)
		XCTAssertNil(state.selectionSession)

		state.resetTransientInteractions()
		XCTAssertEqual(state.selection, .none)
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
		harness.state.selection = Selection(middle)

		harness.operations.cut()
		XCTAssertEqual(harness.film.pxs, [red, .clear, blue])
		XCTAssertEqual(Array(harness.global.pxs.prefix(3)), [red, green, blue])

		harness.film.pxs = [.clear, .clear, .clear]
		harness.operations.paste()
		XCTAssertEqual(harness.film.pxs, [.clear, green, .clear])

		harness.film.pxs = [red, green, blue]
		harness.operations.move(dx: 1)
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
		harness.state.selection = Selection(pair)

		harness.operations.move(dx: 1)
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
		harness.state.selection = Selection(pair)

		harness.operations.move(dx: 1, fill: red)
		XCTAssertEqual(harness.film.pxs, [red, red, green])
	}

	func testMovingASelectionNeverWrapsAcrossRows() {
		let harness = Harness(film: Film(width: 2, height: 2, frames: 1, color: .clear))
		harness.film.pxs = [red, green, blue, red]
		harness.state.selection = Selection(BitSet(count: 4, filled: true))

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
		harness.state.selection = Selection(middle)

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

final class CanvasResizeTests: XCTestCase {
	private let red = Px(rgb: 0x0000FF)
	private let green = Px(rgb: 0x00FF00)
	private let blue = Px(rgb: 0xFF0000)

	private func film(width: Int, height: Int, frames: Int = 1) -> Film {
		var film = Film(width: width, height: height, frames: frames, color: .clear)
		film.pxs = (0..<film.pxs.count).map { index in
			Px(alpha: 255, red: UInt8(index + 1), green: 0, blue: 0)
		}
		return film
	}

	func testShrinkingClipsFromTheTopLeftWithoutResampling() {
		var f = film(width: 3, height: 2)
		let original = f.pxs
		f.resizeCanvas(width: 2, height: 1)

		XCTAssertEqual(f.size, FilmSize(width: 2, height: 1, frames: 1))
		XCTAssertEqual(f.pxs, [original[0], original[1]])
	}

	func testGrowingKeepsThePixelsAndPadsWithTransparency() {
		var f = film(width: 3, height: 2)
		let original = f.pxs
		f.resizeCanvas(width: 4, height: 3)

		XCTAssertEqual(f.size, FilmSize(width: 4, height: 3, frames: 1))
		XCTAssertEqual(f.pxs, [
			original[0], original[1], original[2], .clear,
			original[3], original[4], original[5], .clear,
			.clear, .clear, .clear, .clear,
		])
	}

	func testResizingClipsAndPadsEveryFrameIndependently() {
		var f = film(width: 2, height: 2, frames: 2)
		let original = f.pxs
		f.resizeCanvas(width: 3, height: 1)

		XCTAssertEqual(f.size, FilmSize(width: 3, height: 1, frames: 2))
		XCTAssertEqual(f.pxs, [
			original[0], original[1], .clear,
			original[4], original[5], .clear,
		])
	}

	func testResizingToTheSameSizeIsIdentity() {
		var f = film(width: 3, height: 2, frames: 2)
		let original = f
		f.resizeCanvas(width: 3, height: 2)

		XCTAssertEqual(f, original)
	}

	func testClippedPixelsAreDiscardedRatherThanStretched() {
		var f = Film(width: 2, height: 1, frames: 1, color: .clear)
		f.pxs = [red, green]
		f.resizeCanvas(width: 1, height: 1)
		XCTAssertEqual(f.pxs, [red])

		f.resizeCanvas(width: 2, height: 1)
		XCTAssertEqual(f.pxs, [red, .clear])
		XCTAssertNotEqual(f.pxs, [red, green])
		XCTAssertNotEqual(f.pxs, [red, red])
		XCTAssertNotEqual(f.pxs.last, blue)
	}
}

final class RotateAndFlipTests: XCTestCase {

	/// Storage is row-major with row 0 at the visual top, so `pxs` reads like the picture:
	/// a 3x2 film is `[a, b, c,  d, e, f]` for the rows `a b c` over `d e f`.
	private func film(width: Int, height: Int, frames: Int = 1) -> Film {
		var film = Film(width: width, height: height, frames: frames, color: .clear)
		film.pxs = (0..<film.pxs.count).map { index in
			Px(alpha: 255, red: UInt8(index + 1), green: 0, blue: 0)
		}
		return film
	}

	func testFlipHorizontallyMirrorsEachRowAndKeepsTheSize() {
		var f = film(width: 3, height: 2)
		let p = f.pxs
		f.flipHorizontally()

		XCTAssertEqual(f.size, FilmSize(width: 3, height: 2, frames: 1))
		XCTAssertEqual(f.pxs, [p[2], p[1], p[0], p[5], p[4], p[3]])
	}

	func testFlipVerticallyMirrorsEachColumnAndKeepsTheSize() {
		var f = film(width: 3, height: 2)
		let p = f.pxs
		f.flipVertically()

		XCTAssertEqual(f.size, FilmSize(width: 3, height: 2, frames: 1))
		XCTAssertEqual(f.pxs, [p[3], p[4], p[5], p[0], p[1], p[2]])
	}

	func testRotateRightSwapsTheDimensionsAndMovesTheTopRowToTheRightColumn() {
		var f = film(width: 3, height: 2)
		let p = f.pxs
		f.rotateRight()

		XCTAssertEqual(f.size, FilmSize(width: 2, height: 3, frames: 1))
		XCTAssertEqual(f.pxs, [
			p[3], p[0],
			p[4], p[1],
			p[5], p[2],
		])
	}

	func testRotateLeftSwapsTheDimensionsAndMovesTheTopRowToTheLeftColumn() {
		var f = film(width: 3, height: 2)
		let p = f.pxs
		f.rotateLeft()

		XCTAssertEqual(f.size, FilmSize(width: 2, height: 3, frames: 1))
		XCTAssertEqual(f.pxs, [
			p[2], p[5],
			p[1], p[4],
			p[0], p[3],
		])
	}

	func testFlipsAndOppositeRotationsAreInvolutionsOrInverses() {
		let original = film(width: 3, height: 2, frames: 2)

		var horizontal = original
		horizontal.flipHorizontally()
		XCTAssertNotEqual(horizontal, original)
		horizontal.flipHorizontally()
		XCTAssertEqual(horizontal, original)

		var vertical = original
		vertical.flipVertically()
		XCTAssertNotEqual(vertical, original)
		vertical.flipVertically()
		XCTAssertEqual(vertical, original)

		var f = original
		f.rotateRight()
		XCTAssertNotEqual(f, original)
		f.rotateLeft()
		XCTAssertEqual(f, original)

		f.rotateRight()
		f.rotateRight()
		f.rotateRight()
		f.rotateRight()
		XCTAssertEqual(f, original)
	}

	func testFourRotationsMatchTwoFlipsAfterTwoQuarterTurns() {
		var rotated = film(width: 3, height: 2, frames: 2)
		rotated.rotateRight()
		rotated.rotateRight()

		var flipped = film(width: 3, height: 2, frames: 2)
		flipped.flipHorizontally()
		flipped.flipVertically()

		XCTAssertEqual(rotated, flipped)
	}

	func testEveryFrameIsTransformedIndependently() {
		var f = film(width: 2, height: 2, frames: 2)
		let p = f.pxs
		f.rotateRight()

		XCTAssertEqual(f.size, FilmSize(width: 2, height: 2, frames: 2))
		XCTAssertEqual(Array(f.pxs.prefix(4)), [p[2], p[0], p[3], p[1]])
		XCTAssertEqual(Array(f.pxs.suffix(4)), [p[6], p[4], p[7], p[5]])
	}

	func testSingleRowAndSingleColumnFilmsTranspose() {
		var row = Film(width: 3, height: 1, frames: 1, color: .clear)
		row.pxs = [Px(rgb: 0x0000FF), Px(rgb: 0x00FF00), Px(rgb: 0xFF0000)]
		let p = row.pxs

		row.rotateRight()
		XCTAssertEqual(row.size, FilmSize(width: 1, height: 3, frames: 1))
		XCTAssertEqual(row.pxs, [p[0], p[1], p[2]])

		row.rotateRight()
		XCTAssertEqual(row.size, FilmSize(width: 3, height: 1, frames: 1))
		XCTAssertEqual(row.pxs, [p[2], p[1], p[0]])
	}
}

@MainActor
final class TransformOperationTests: XCTestCase {

	func testTransformsDropAStaleSelection() {
		let harness = Harness(film: Film(width: 3, height: 2, frames: 1, color: .clear))
		let transforms: [(String, (Operations) -> () -> Void)] = [
			("rotateLeft", { op in op.rotateLeft }),
			("rotateRight", { op in op.rotateRight }),
			("flipHorizontally", { op in op.flipHorizontally }),
			("flipVertically", { op in op.flipVertically }),
		]

		for (name, transform) in transforms {
			harness.state.selection = Selection(BitSet(count: harness.film.size.count, filled: true))
			transform(harness.operations)()
			XCTAssertEqual(harness.state.selection, .none, name)
		}
	}

	func testRotatingSwapsTheFilmDimensionsThroughOperations() {
		let harness = Harness(film: Film(width: 4, height: 2, frames: 1, color: .clear))

		harness.operations.rotateRight()
		XCTAssertEqual(harness.film.size, FilmSize(width: 2, height: 4, frames: 1))

		harness.operations.rotateLeft()
		XCTAssertEqual(harness.film.size, FilmSize(width: 4, height: 2, frames: 1))

		harness.operations.flipHorizontally()
		XCTAssertEqual(harness.film.size, FilmSize(width: 4, height: 2, frames: 1))
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

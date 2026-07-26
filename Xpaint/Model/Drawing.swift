import AppKit
import SwiftUI

extension EditorView {

	func pxl(at location: CGPoint) -> PxL {
		PxL(
			x: Int(location.x / state.magnification),
			y: Int(film.size.cg.height - location.y / state.magnification),
			z: state.layer
		)
	}

	var drawingController: some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged { gesture in
				let point = pxl(at: gesture.location)
				switch state.tool {
				case .selection:
					state.beginSelection(at: pxl(at: gesture.startLocation), mode: selectionMode)
					state.updateSelection(to: point, size: film.size)
				case .line:
					state.beginLineGesture(at: pxl(at: gesture.startLocation))
					state.updateLine(to: point, snapped: modifierFlags.contains(.shift))
				default:
					draw(at: point)
				}
			}
			.onEnded { gesture in
				switch state.tool {
				case .selection:
					state.updateSelection(to: pxl(at: gesture.location), size: film.size)
					state.endSelection()
				case .line:
					state.updateLine(
						to: pxl(at: gesture.location),
						snapped: modifierFlags.contains(.shift)
					)
					if let (start, end) = state.endLineGesture() {
						commitLine(from: start, to: end)
					}
				case .eyedropper:
					break
				default:
					undoGroup(state.tool.actionName)
				}
			}
	}

	func hoverLine(at location: CGPoint) {
		guard state.tool == .line else { return }
		state.hoverLine(
			to: pxl(at: location),
			snapped: modifierFlags.contains(.shift)
		)
	}
}

private extension EditorView {
	var modifierFlags: NSEvent.ModifierFlags {
		NSEvent.modifierFlags
	}

	var selectionMode: SelectionMode {
		SelectionMode(
			shift: modifierFlags.contains(.shift),
			option: modifierFlags.contains(.option)
		)
	}

	func undoGroup(_ name: String, _ body: () -> Void = {}) {
		undoManager?.beginUndoGrouping()
		body()
		undoManager?.setActionName(name)
		undoManager?.endUndoGrouping()
	}

	func draw(at pxl: PxL) {
		switch state.tool {
		case .pencil: pencil(at: pxl)
		case .eraser: pencil(.clear, at: pxl)
		case .bucket: bucket(at: pxl)
		case .replace: replace(at: pxl)
		case .eyedropper: state.primaryColor = film[pxl]
		case .selection, .line: break
		}
	}

	func pencil(_ px: Px? = .none, at pxl: PxL) {
		let px = px ?? (pxl.isEven ? state.primaryColor : state.ditherColor)
		film.drawPixel(px, at: pxl, selection: state.selection)
	}

	func bucket(at pxl: PxL) {
		film.floodFill(
			at: pxl,
			primary: state.primaryColor,
			secondary: state.ditherColor,
			selection: state.selection
		)
	}

	func replace(at pxl: PxL) {
		film.replaceColor(
			at: pxl,
			primary: state.primaryColor,
			secondary: state.ditherColor,
			selection: state.selection
		)
	}

	func commitLine(from start: PxL, to end: PxL) {
		undoGroup(Tool.line.actionName) {
			film.drawLine(
				from: start,
				to: end,
				primary: state.primaryColor,
				secondary: state.ditherColor,
				selection: state.selection
			)
		}
	}
}

extension Film {
	mutating func drawPixel(_ pixel: Px, at point: PxL, selection: BitSet?) {
		guard let index = size.index(at: point.xy), selection.allows(index) else { return }
		withMutableLayer(point.z) { pixels in pixels[index] = pixel }
	}

	mutating func floodFill(
		at point: PxL,
		primary: Px,
		secondary: Px,
		selection: BitSet?
	) {
		let size = size
		let start = point.xy
		guard let startIndex = size.index(at: start), selection.allows(startIndex) else { return }

		withMutableLayer(point.z) { pixels in
			let original = pixels[startIndex]
			pixels[startIndex] = start.isEven ? primary : secondary

			var visited = BitSet(count: size.count)
			visited[startIndex] = true
			var front = [start]
			var next: [PxL] = []
			while !front.isEmpty {
				next.removeAll(keepingCapacity: true)
				for current in front {
					for neighbor in current.neighbors {
						guard let index = size.index(at: neighbor),
							!visited[index],
							selection.allows(index),
							pixels[index] == original
						else { continue }
						pixels[index] = neighbor.isEven ? primary : secondary
						visited[index] = true
						next.append(neighbor)
					}
				}
				swap(&front, &next)
			}
		}
	}

	mutating func replaceColor(
		at point: PxL,
		primary: Px,
		secondary: Px,
		selection: BitSet?
	) {
		guard let absoluteIndex = size.index(at: point) else { return }
		let original = pxs[absoluteIndex]
		withMutableLayer(point.z) { [size] pixels in
			for index in pixels.indices where selection.allows(index) && pixels[index] == original {
				pixels[index] = size.pxl(at: index).isEven ? primary : secondary
			}
		}
	}

	mutating func drawLine(
		from start: PxL,
		to end: PxL,
		primary: Px,
		secondary: Px,
		selection: BitSet?
	) {
		let size = size
		withMutableLayer(start.z) { pixels in
			for point in rasterizedLine(from: start, to: end) {
				guard let index = size.index(at: point.xy), selection.allows(index) else { continue }
				pixels[index] = point.isEven ? primary : secondary
			}
		}
	}
}

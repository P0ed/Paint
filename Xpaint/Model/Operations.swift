import SwiftUI

struct Operations {
	@Binding var state: EditorState
	@Binding var palette: Palette
	@Binding var shader: Shader
	@Binding var film: Film
	@Binding var global: Film
}

extension Operations {

	func scaleToFit() {
		state.setScale(film.size.zoomToFit(state.size))
	}

	func shiftLeft() {
		mutateSelectedPixels { px in
			px.red <<= 1
			px.green <<= 1
			px.blue <<= 1
		}
	}

	func shiftRight() {
		mutateSelectedPixels { px in
			px.red >>= 1
			px.green >>= 1
			px.blue >>= 1
		}
	}

	func makeMonochrome() {
		mutateSelectedPixels { px in
			let avg = UInt8(
				clamping: (UInt16(px.red) + UInt16(px.green) + UInt16(px.blue)) / 3
			)
			px.red = avg
			px.green = avg
			px.blue = avg
		}
	}

	func exportFile<ContentType: TypeProvider>(_ type: ContentType.Type) {
		let document = Document<ContentType>(film: film)
		state.exportedFilm = Document(converting: document, mask: state.visibleLayers).film
		state.exporting = true
	}

	func wipeLayer() {
		mutateSelectedPixels { px in px = .clear }
	}

	func move(dx: Int = 0, dy: Int = 0) {
		transformLayer { film, layer in film.move(layer: layer, dx: dx, dy: dy) }
	}

	func cut() {
		copy()
		mutateSelectedPixels { px in px = .clear }
	}

	func copy() {
		let layer = film.pxs[film.range(state.layer)]
		global.pxs.replaceSubrange(0..<layer.count, with: layer)
		global.size = film.size
	}

	func paste() {
		film.withMutableLayer(state.layer) { [
			size = film.size,
			gs = global.size,
			src = global.pxs,
			selection = state.selection
		] dst in
			for y in 0 ..< min(size.height, gs.height) {
				for x in 0 ..< min(size.width, gs.width) {
					let index = y * size.width + x
					if selection.allows(index) {
						dst[index] = dst[index] + src[y * gs.width + x]
					}
				}
			}
		}
	}

	func applyShader() {
		transformLayer { film, layer in shader(layer, &film) }
	}
}

private extension Operations {

	func mutateSelectedPixels(_ body: (inout Px) -> Void) {
		let selection = state.selection
		film.withMutableLayer(state.layer) { pixels in
			for index in pixels.indices where selection.allows(index) {
				body(&pixels[index])
			}
		}
	}

	/// Runs `transform` on a scratch copy, then merges the active layer back through the selection.
	func transformLayer(_ transform: (inout Film, Int) -> Void) {
		let layer = state.layer
		var scratch = film
		transform(&scratch, layer)
		film.mergeLayer(layer, from: scratch.pxs[scratch.range(layer)], selection: state.selection)
	}
}

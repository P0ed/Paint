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
		film.withMutablePixel(state.layer) { px in
			px.red <<= 1
			px.green <<= 1
			px.blue <<= 1
		}
	}

	func shiftRight() {
		film.withMutablePixel(state.layer) { px in
			px.red >>= 1
			px.green >>= 1
			px.blue >>= 1
		}
	}

	func makeMonochrome() {
		film.withMutablePixel(state.layer) { px in
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
		film.withMutablePixel(state.layer) { px in px = .clear }
	}

	func move(dx: Int = 0, dy: Int = 0) {
		film.move(layer: state.layer, dx: dx, dy: dy)
	}

	func cut() {
		copy()
		film.withMutablePixel(state.layer) { px in px = .clear }
	}

	func copy() {
		let layer = film.pxs[film.range(state.layer)]
		global.pxs.replaceSubrange(0 ..< layer.count - 1, with: layer)
		global.size = film.size
	}

	func paste() {
		film.withMutableLayer(state.layer) { [
			size = film.size,
			gs = global.size,
			src = global.pxs
		] dst in
			for y in 0 ..< min(size.height, gs.height) {
				for x in 0 ..< min(size.width, gs.width) {
					dst[y * size.width + x] = dst[y * size.width + x] + src[y * gs.width + x]
				}
			}
		}
	}

	func applyShader() {
		shader(state.layer, &film)
	}
}

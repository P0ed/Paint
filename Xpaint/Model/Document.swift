import SwiftUI
import UniformTypeIdentifiers

struct Document<ContentType: TypeProvider>: FileDocument {
	var film: Film

	var size: FilmSize { film.size }
	var pxs: [Px] {
		get { film.pxs }
		set { film.pxs = newValue }
	}

	static var readableContentTypes: [UTType] { [ContentType.type] }
	static var frames: Int { ContentType.type == .pxd ? 4 : 1 }

	init(film: Film) {
		self.film = film
	}

	init(width: Int = 32, height: Int = 32, color: Px? = .white) {
		film = Film(width: width, height: height, frames: Self.frames, color: color)
	}

	init<T: TypeProvider>(converting file: Document<T>, mask: Int = 0xF) where T.ExportType == ContentType {
		film = Film(
			size: FilmSize(
				width: file.size.width,
				height: file.size.height,
				frames: Self.frames
			)
		)
		film.merge(file.film, mask: mask)
	}

	init(configuration: ReadConfiguration) throws {
		let data = try configuration.file.regularFileContents
			.throwing("Failed to read file")

		let image = try (NSBitmapImageRep(data: data)?.cgImage)
			.throwing("Failed to open image")

		if Self.frames == 4, image.height & 0b11 != 0 {
			throw Err("Corrupted file")
		}
		let size = FilmSize(
			width: image.width,
			height: image.height / Self.frames,
			frames: Self.frames
		)
		if size.count > FilmSize.max.count {
			throw Err("File too large")
		}
		film = Film(size: size)
		film.drawFilm(image)
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		let film = try film.image()
			.throwing("Failed to create CGImage")

		let data = try NSBitmapImageRep(cgImage: film)
			.representation(using: .png, properties: [:])
			.throwing("Failed to create PNG representation")

		return FileWrapper(regularFileWithContents: data)
	}
}

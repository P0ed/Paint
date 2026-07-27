import SwiftUI

extension EditorView {

	@ToolbarContentBuilder
	var toolbar: some ToolbarContent {
		if ContentType.type == .pxd {
			ToolbarItemGroup {
				ForEach(0..<4) { idx in
					LayerButton(index: idx, state: $state)
				}
			}
			ToolbarItemGroup { Spacer() }
		}
		ToolbarItemGroup {
			ToolButton(tool: .pencil, state: $state.tool)
			ToolButton(tool: .line, state: $state.tool)
			ToolButton(tool: .eyedropper, state: $state.tool)
			ToolButton(tool: .eraser, state: $state.tool)
			ToolButton(tool: .bucket, state: $state.tool)
			ToolButton(tool: .replace, state: $state.tool)
			ToolButton(tool: .selection, state: $state.tool)
		}
		ToolbarItemGroup { Spacer() }
		ToolbarItemGroup {
			ActionButton(
				name: "Export",
				image: "square.and.arrow.up",
				shortcut: "E",
				modifiers: .command,
				action: { operations.exportFile(ContentType.self) }
			)
		}
	}
}

struct ToolButton: View {
	var tool: Tool
	@Binding
	var state: Tool

	var body: some View {
		Button(tool.actionName, systemImage: tool.systemImage, action: { state = tool })
			.foregroundStyle(state == tool ? Color.accent : .primary)
			.keyboardShortcut(KeyEquivalent(tool.shortcutCharacter), modifiers: [])
	}
}

struct ActionButton: View {
	var name: String
	var image: String
	var shortcut: Character
	var modifiers: EventModifiers = []
	var disabled: Bool = false
	var action: () -> Void

	var body: some View {
		Button(name, systemImage: image, action: action)
			.disabled(disabled)
			.keyboardShortcut(KeyEquivalent(shortcut), modifiers: modifiers)
	}
}

struct LayerButton: View {
	var index: Int
	@Binding
	var state: EditorState

	static let names: [String] = ["A", "B", "C", "D"]

	var name: String { Self.names[index & 0b11] }
	var isVisible: Bool { state.visibleLayers & 1 << index != 0 }

	var body: some View {
		Button(
			"Layer \(name)",
			systemImage: "\(name.lowercased()).square\(isVisible ? ".fill" : "")",
			action: {
				if state.layer == index {
					state.visibleLayers = state.visibleLayers ^ 1 << index
				} else {
					state.layer = index
				}
			}
		)
		.foregroundStyle(state.layer == index ? Color.accent : .primary)
		.keyboardShortcut(.init(name.first!), modifiers: .shift)
	}
}

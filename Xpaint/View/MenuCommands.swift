import SwiftUI

extension FocusedValues {
	@Entry var operations: Operations?
}

extension Operations? {
	var actionsDisabled: Bool { self?.state.dialogPresented ?? true }
}

struct MenuCommands: Commands {
	@FocusedValue(\.operations) var op

	var body: some Commands {
		if !op.actionsDisabled {
			CommandGroup(replacing: .pasteboard) {
				ActionButton(
					name: "Cut",
					image: "scissors",
					shortcut: "X",
					modifiers: .command,
					action: { op?.cut() }
				)
				ActionButton(
					name: "Copy",
					image: "document.on.document",
					shortcut: "C",
					modifiers: .command,
					action: { op?.copy() }
				)
				ActionButton(
					name: "Paste",
					image: "document.on.clipboard",
					shortcut: "V",
					modifiers: .command,
					action: { op?.paste() }
				)
			}
		}
		CommandGroup(before: .windowSize) {
			ActionButton(
				name: "Size to fit",
				image: "arrow.up.left.and.down.right.magnifyingglass",
				shortcut: "9",
				disabled: op.actionsDisabled,
				action: { op?.scaleToFit() }
			)
			ActionButton(
				name: "Actual size",
				image: "1.magnifyingglass",
				shortcut: "0",
				disabled: op.actionsDisabled,
				action: { op?.state.setScale(1.0) }
			)
			ActionButton(
				name: "Zoom out",
				image: "minus.magnifyingglass",
				shortcut: "-",
				disabled: op.actionsDisabled,
				action: { op?.state.setScale((op?.state.magnification ?? 1.0) / 2.0) }
			)
			ActionButton(
				name: "Zoom in",
				image: "plus.magnifyingglass",
				shortcut: "=",
				disabled: op.actionsDisabled,
				action: { op?.state.setScale((op?.state.magnification ?? 1.0) * 2.0) }
			)
			Divider()
		}
		CommandMenu("Selection") {
			ActionButton(
				name: "Deselect",
				image: "rectangle.dashed",
				shortcut: "A",
				modifiers: [.command, .shift],
				disabled: op.actionsDisabled,
				action: { op?.state.clearSelection() }
			)
		}
		CommandMenu("Operations") {
			ActionButton(
				name: "Resize",
				image: "square.resize",
				shortcut: "R",
				modifiers: .command,
				disabled: op.actionsDisabled,
				action: { op?.state.sizeDialogPresented = true }
			)
			ActionButton(
				name: "Wipe",
				image: "windshield.rear.and.wiper",
				shortcut: KeyEquivalent.delete.character,
				disabled: op.actionsDisabled,
				action: { op?.wipeLayer() }
			)
			ActionButton(
				name: "Fill",
				image: "paintbrush.fill",
				shortcut: KeyEquivalent.delete.character,
				modifiers: .option,
				disabled: op.actionsDisabled,
				action: { op?.fillLayer() }
			)
			Divider()
			ActionButton(
				name: "Make monochrome",
				image: "sum",
				shortcut: "G",
				modifiers: .command,
				disabled: op.actionsDisabled,
				action: { op?.makeMonochrome() }
			)
			ActionButton(
				name: "Shift left",
				image: "chevron.left.2",
				shortcut: "<",
				disabled: op.actionsDisabled,
				action: { op?.shiftLeft() }
			)
			ActionButton(
				name: "Shift right",
				image: "chevron.right.2",
				shortcut: ">",
				disabled: op.actionsDisabled,
				action: { op?.shiftRight() }
			)
			Divider()
			Menu("Shader") {
				ActionButton(
					name: "Edit",
					image: "record.circle.fill",
					shortcut: "E",
					modifiers: .control,
					disabled: op.actionsDisabled,
					action: { op?.state.shaderDialogPresented = true }
				)
				ActionButton(
					name: "Apply",
					image: "play.fill",
					shortcut: "A",
					modifiers: .control,
					disabled: op.actionsDisabled,
					action: { op?.applyShader() }
				)
			}
		}
		if op?.film.size.frames ?? 0 > 1 {
			CommandMenu("Layers") {
				ActionButton(
					name: "Previous layer",
					image: "square.3.layers.3d.bottom.filled",
					shortcut: "\u{19}",
					disabled: op.actionsDisabled,
					action: { op?.state.prevLayer() }
				)
				ActionButton(
					name: "Next layer",
					image: "square.3.layers.3d.top.filled",
					shortcut: "\u{9}",
					disabled: op.actionsDisabled,
					action: { op?.state.nextLayer() }
				)
				ActionButton(
					name: "Toggle layer",
					image: "square.3.layers.3d",
					shortcut: " ",
					disabled: op.actionsDisabled,
					action: { op?.state.toggleLayer() }
				)
			}
		}
		CommandMenu("Colors") {
			ActionButton(
				name: "Swap colors",
				image: "rectangle.2.swap",
				shortcut: "x",
				disabled: op.actionsDisabled,
				action: { op?.state.swapColors() }
			)
			ActionButton(
				name: "Pick color",
				image: "paintpalette",
				shortcut: "§",
				disabled: op.actionsDisabled,
				action: { op?.state.colorDialogPresented = true }
			)
		}
	}
}

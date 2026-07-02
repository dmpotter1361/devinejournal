// Cross-component flag: is the entry editor holding unsaved changes?
// EntryEditor keeps it current; SearchOverlay (and anything else that
// navigates away) checks it before leaving the editor.
export const editorDirty = { current: false };

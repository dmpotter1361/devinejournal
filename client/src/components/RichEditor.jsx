import { useEffect, useReducer, useRef, useState } from 'react';
import { useEditor, EditorContent } from '@tiptap/react';
import { StarterKit } from '@tiptap/starter-kit';
import { Underline } from '@tiptap/extension-underline';
import { TextStyle } from '@tiptap/extension-text-style';
import { Color } from '@tiptap/extension-color';
import { Highlight } from '@tiptap/extension-highlight';
import { TextAlign } from '@tiptap/extension-text-align';
import { Placeholder } from '@tiptap/extension-placeholder';
import { CaptionedImage } from './CaptionedImage';
import { FontStyles } from './FontStyles';
import './RichEditor.css';

const FONTS = [
  { label: 'Default', value: '' },
  { label: 'Cormorant', value: '"Cormorant Garamond", Georgia, serif' },
  { label: 'Caveat', value: 'Caveat, cursive' },
  { label: 'Dancing Script', value: '"Dancing Script", cursive' },
  { label: 'Indie Flower', value: '"Indie Flower", cursive' },
  { label: 'Lora', value: 'Lora, serif' },
  { label: 'Nunito', value: 'Nunito, sans-serif' },
  { label: 'Mono', value: 'ui-monospace, "Courier New", monospace' },
];
const SIZES = [
  { label: 'S', value: '13px' },
  { label: 'M', value: '' },
  { label: 'L', value: '20px' },
  { label: 'XL', value: '28px' },
];
const EMOJIS = [
  '🌙','✨','🌸','🔥','💫','🌿','💜','🌊','🌻','🦋','🌹','🌺','🌼','🌠',
  '😊','😔','🥰','😍','😌','😢','😴','🥳','😇','💪','🙏','💖','💔','❤️',
  '🐱','🐶','🦊','🌈','☀️','⭐','☔','❄️','🍂','☕','🍵','🍰','📖','✍️',
];

function useEditorTick(editor) {
  const [, tick] = useReducer((n) => n + 1, 0);
  useEffect(() => {
    if (!editor) return;
    editor.on('transaction', tick);
    return () => editor.off('transaction', tick);
  }, [editor]);
}

function Btn({ on, active, children, title }) {
  return (
    <button
      type="button"
      className={`re-tool ${active ? 'on' : ''}`}
      onMouseDown={(e) => e.preventDefault()}
      onClick={on}
      title={title}
    >
      {children}
    </button>
  );
}

export default function RichEditor({ value, onChange, placeholder, paperStyle, insertImageFn }) {
  const [emojiOpen, setEmojiOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const emojiRef = useRef(null);
  const fileRef = useRef(null);
  const editorRef = useRef(null);
  const insertRef = useRef(insertImageFn);
  insertRef.current = insertImageFn;

  const editor = useEditor({
    extensions: [
      StarterKit,
      Underline,
      TextStyle,
      Color,
      Highlight.configure({ multicolor: true }),
      TextAlign.configure({ types: ['heading', 'paragraph'] }),
      FontStyles,
      CaptionedImage.configure({ inline: false, allowBase64: true }),
      Placeholder.configure({ placeholder: placeholder || 'Write here… 🌙' }),
    ],
    content: value || '',
    onUpdate: ({ editor }) => onChange?.(editor.getHTML()),
    editorProps: {
      handleDrop(view, event, _slice, moved) {
        if (moved) return false;
        const imgs = imageFiles(event.dataTransfer?.files);
        if (!imgs.length) return false;
        event.preventDefault();
        const pos = view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos ?? null;
        insertFiles(editorRef.current, imgs, pos, insertRef, setUploading);
        return true;
      },
      handlePaste(_view, event) {
        const imgs = imageFiles(event.clipboardData?.files);
        if (!imgs.length) return false;
        event.preventDefault();
        insertFiles(editorRef.current, imgs, null, insertRef, setUploading);
        return true;
      },
    },
  });

  useEditorTick(editor);
  editorRef.current = editor;

  // Keep content in sync when parent changes the value (e.g. loading entry)
  const lastValue = useRef(value);
  useEffect(() => {
    if (!editor || value === lastValue.current) return;
    lastValue.current = value;
    if (value !== editor.getHTML()) {
      editor.commands.setContent(value || '', false);
    }
  }, [editor, value]);

  useEffect(() => {
    const h = (e) => {
      if (emojiRef.current && !emojiRef.current.contains(e.target)) setEmojiOpen(false);
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, []);

  if (!editor) return null;

  const insertEmoji = (e) => {
    editor.chain().focus().insertContent(e).run();
    setEmojiOpen(false);
  };

  const onPickFile = async (e) => {
    const imgs = imageFiles(e.target.files);
    e.target.value = '';
    if (!imgs.length) return;
    await insertFiles(editor, imgs, null, insertRef, setUploading);
  };

  return (
    <div className="rich-editor">
      <div className="re-toolbar" role="toolbar" aria-label="Formatting">
        <Btn on={() => editor.chain().focus().toggleBold().run()} active={editor.isActive('bold')} title="Bold"><b>B</b></Btn>
        <Btn on={() => editor.chain().focus().toggleItalic().run()} active={editor.isActive('italic')} title="Italic"><i>I</i></Btn>
        <Btn on={() => editor.chain().focus().toggleUnderline().run()} active={editor.isActive('underline')} title="Underline"><u>U</u></Btn>
        <Btn on={() => editor.chain().focus().toggleStrike().run()} active={editor.isActive('strike')} title="Strikethrough"><s>S</s></Btn>
        <Btn on={() => editor.chain().focus().toggleHeading({ level: 2 }).run()} active={editor.isActive('heading', { level: 2 })} title="Heading">H</Btn>
        <select
          className="re-select"
          title="Font"
          value={editor.getAttributes('textStyle').fontFamily || ''}
          onMouseDown={(e) => e.stopPropagation()}
          onChange={(e) => {
            const v = e.target.value;
            v ? editor.chain().focus().setFontFamily(v).run()
              : editor.chain().focus().unsetFontFamily().run();
          }}
        >
          {FONTS.map((f) => <option key={f.label} value={f.value}>{f.label}</option>)}
        </select>
        <select
          className="re-select size"
          title="Font size"
          value={editor.getAttributes('textStyle').fontSize || ''}
          onMouseDown={(e) => e.stopPropagation()}
          onChange={(e) => {
            const v = e.target.value;
            v ? editor.chain().focus().setFontSize(v).run()
              : editor.chain().focus().unsetFontSize().run();
          }}
        >
          {SIZES.map((s) => <option key={s.label} value={s.value}>{s.label}</option>)}
        </select>
        <label className="re-tool color" title="Text color">
          🎨
          <input
            type="color"
            onChange={(e) => editor.chain().focus().setColor(e.target.value).run()}
            value={editor.getAttributes('textStyle').color || '#c9a84c'}
          />
        </label>
        <Btn on={() => editor.chain().focus().toggleHighlight({ color: '#4a3a00' }).run()} active={editor.isActive('highlight')} title="Highlight">🖍️</Btn>
        <Btn on={() => editor.chain().focus().toggleBulletList().run()} active={editor.isActive('bulletList')} title="Bullet list">•</Btn>
        <Btn on={() => editor.chain().focus().toggleOrderedList().run()} active={editor.isActive('orderedList')} title="Numbered list">1.</Btn>
        <Btn on={() => editor.chain().focus().setTextAlign('left').run()} active={editor.isActive({ textAlign: 'left' })} title="Align left">⬅</Btn>
        <Btn on={() => editor.chain().focus().setTextAlign('center').run()} active={editor.isActive({ textAlign: 'center' })} title="Center">⬌</Btn>
        <div className="re-emoji-wrap" ref={emojiRef}>
          <Btn on={() => setEmojiOpen((o) => !o)} active={emojiOpen} title="Emoji">😊</Btn>
          {emojiOpen && (
            <div className="re-emoji-pop">
              {EMOJIS.map((e) => (
                <button key={e} type="button" className="re-emoji-item" onClick={() => insertEmoji(e)}>{e}</button>
              ))}
            </div>
          )}
        </div>
        <Btn on={() => fileRef.current?.click()} active={uploading} title="Insert image">
          {uploading ? '⏳' : '🖼️'}
        </Btn>
        <input ref={fileRef} type="file" accept="image/*" multiple hidden onChange={onPickFile} />
      </div>
      <div className={`editor-paper ${paperStyle ? `paper-${paperStyle}` : ''}`}>
        <EditorContent editor={editor} className="re-content" />
      </div>
    </div>
  );
}

// Exposed so parent can imperatively insert an image src.
export function editorInsertImage(editor, src) {
  editor?.chain().focus().setImage({ src }).run();
}

const imageFiles = (fileList) => [...(fileList || [])].filter((f) => /^image\//.test(f.type));

async function insertFiles(editor, files, pos, insertRef, setUploading) {
  if (!editor) return;
  setUploading(true);
  try {
    for (const file of files) {
      try {
        const src = insertRef.current
          ? await insertRef.current(file)
          : await resizeToBase64(file);
        const chain = editor.chain().focus();
        if (pos != null) chain.setTextSelection(pos);
        chain.insertContent([{ type: 'image', attrs: { src } }]).run();
      } catch (err) {
        alert('Image failed: ' + (err.message || 'try again'));
      }
    }
  } finally {
    setUploading(false);
  }
}

// Client-side resize + JPEG compress (max 1400px, quality 0.88)
export async function resizeToBase64(file, maxPx = 1400) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      URL.revokeObjectURL(url);
      let { width, height } = img;
      if (width > maxPx || height > maxPx) {
        if (width > height) { height = Math.round((height / width) * maxPx); width = maxPx; }
        else { width = Math.round((width / height) * maxPx); height = maxPx; }
      }
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      canvas.getContext('2d').drawImage(img, 0, 0, width, height);
      resolve(canvas.toDataURL('image/jpeg', 0.88));
    };
    img.onerror = () => reject(new Error('Could not load image'));
    img.src = url;
  });
}

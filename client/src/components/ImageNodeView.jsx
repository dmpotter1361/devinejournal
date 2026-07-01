import { useRef } from 'react';
import { NodeViewWrapper } from '@tiptap/react';

export default function ImageNodeView({ node, updateAttributes, deleteNode, editor, selected }) {
  const { src, alt, caption, width, align = 'center' } = node.attrs;
  const editable = editor.isEditable;
  const imgRef = useRef(null);

  const startResize = (e) => {
    e.preventDefault();
    e.stopPropagation();
    const startX = e.clientX;
    const startW = imgRef.current.getBoundingClientRect().width;
    const maxW = imgRef.current.closest('.ProseMirror')?.getBoundingClientRect().width || 640;
    const onMove = (ev) => {
      const w = Math.min(Math.max(60, Math.round(startW + (ev.clientX - startX))), Math.round(maxW));
      updateAttributes({ width: w });
    };
    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
  };

  const FbBtn = ({ on, active, children, title, danger }) => (
    <button
      type="button"
      className={`ds-fb-btn ${active ? 'on' : ''} ${danger ? 'danger' : ''}`}
      contentEditable={false}
      onMouseDown={(e) => e.preventDefault()}
      onClick={on}
      title={title}
    >
      {children}
    </button>
  );

  return (
    <NodeViewWrapper as="figure" className={`ds-figure ds-align-${align} ${selected ? 'sel' : ''}`}>
      <div className="ds-figure-imgwrap" style={width ? { width: `${width}px` } : undefined}>
        {editable && (
          <div className="ds-figure-bar" contentEditable={false}>
            <span className="ds-fb-btn grab" data-drag-handle title="Drag to reorder">⠿</span>
            <span className="ds-fb-sep" />
            <FbBtn active={align === 'left'} on={() => updateAttributes({ align: 'left' })} title="Float left">⇤</FbBtn>
            <FbBtn active={align === 'center'} on={() => updateAttributes({ align: 'center' })} title="Center">▢</FbBtn>
            <FbBtn active={align === 'right'} on={() => updateAttributes({ align: 'right' })} title="Float right">⇥</FbBtn>
            <span className="ds-fb-sep" />
            <FbBtn on={() => updateAttributes({ width: null })} title="Full width">⤢</FbBtn>
            <FbBtn danger on={() => deleteNode()} title="Remove photo">✕</FbBtn>
          </div>
        )}
        <img
          ref={imgRef}
          src={src}
          alt={alt || caption || ''}
          draggable={false}
          style={width ? { width: '100%' } : undefined}
        />
        {editable && <span className="ds-figure-resize" onPointerDown={startResize} title="Drag to resize" />}
      </div>
      {editable ? (
        <input
          className="ds-figure-cap"
          contentEditable={false}
          value={caption || ''}
          placeholder="Add a caption…"
          onChange={(e) => updateAttributes({ caption: e.target.value })}
          onKeyDown={(e) => e.stopPropagation()}
          onMouseDown={(e) => e.stopPropagation()}
        />
      ) : (
        caption ? <figcaption className="ds-figure-cap-static">{caption}</figcaption> : null
      )}
    </NodeViewWrapper>
  );
}

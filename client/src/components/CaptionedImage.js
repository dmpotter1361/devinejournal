import { Image } from '@tiptap/extension-image';
import { ReactNodeViewRenderer } from '@tiptap/react';
import ImageNodeView from './ImageNodeView.jsx';

export const CaptionedImage = Image.extend({
  name: 'image',
  draggable: true,

  addAttributes() {
    return {
      ...this.parent?.(),
      caption: {
        default: '',
        renderHTML: () => ({}),
        parseHTML: () => undefined,
      },
      width: {
        default: null,
        parseHTML: (el) => {
          const w = el.getAttribute('width');
          return w ? parseInt(w, 10) : null;
        },
        renderHTML: (attrs) => (attrs.width ? { width: attrs.width } : {}),
      },
      align: {
        default: 'center',
        parseHTML: () => undefined,
        renderHTML: () => ({}),
      },
    };
  },

  parseHTML() {
    return [
      {
        tag: 'figure.ds-figure',
        getAttrs: (el) => {
          const img = el.querySelector('img');
          if (!img) return false;
          const cap = el.querySelector('figcaption');
          const w = img.getAttribute('width');
          return {
            src: img.getAttribute('src'),
            alt: img.getAttribute('alt'),
            title: img.getAttribute('title'),
            caption: cap ? cap.textContent : '',
            width: w ? parseInt(w, 10) : null,
            align: el.getAttribute('data-align') || 'center',
          };
        },
      },
      { tag: 'img[src]' },
    ];
  },

  renderHTML({ node, HTMLAttributes }) {
    const { caption, align } = node.attrs;
    return [
      'figure',
      { class: `ds-figure ds-align-${align || 'center'}`, 'data-align': align || 'center' },
      ['img', HTMLAttributes],
      ['figcaption', {}, caption || ''],
    ];
  },

  addNodeView() {
    return ReactNodeViewRenderer(ImageNodeView);
  },
});

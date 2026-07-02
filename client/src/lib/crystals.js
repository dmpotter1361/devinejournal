// Crystal of the Day — a small daily correspondence, date-seeded like the
// affirmation and tarot card so it holds steady all day.
export const CRYSTALS = [
  { name: 'Amethyst',         emoji: '🔮', props: 'calm, intuition, and protection' },
  { name: 'Rose Quartz',      emoji: '🌸', props: 'gentle love and self-compassion' },
  { name: 'Clear Quartz',     emoji: '🤍', props: 'clarity and amplified intention' },
  { name: 'Moonstone',        emoji: '🌙', props: 'new beginnings and inner knowing' },
  { name: 'Citrine',          emoji: '☀️', props: 'warmth, joy, and abundance' },
  { name: 'Labradorite',      emoji: '✨', props: 'magic and quiet transformation' },
  { name: 'Black Tourmaline', emoji: '🖤', props: 'grounding and shielding' },
  { name: 'Selenite',         emoji: '🕯️', props: 'cleansing and peace' },
  { name: 'Lapis Lazuli',     emoji: '💙', props: 'truth and inner wisdom' },
  { name: 'Carnelian',        emoji: '🔥', props: 'courage and creative fire' },
  { name: 'Green Aventurine', emoji: '🍀', props: 'luck and open-hearted growth' },
  { name: 'Obsidian',         emoji: '🌑', props: 'honest shadow and protection' },
  { name: "Tiger's Eye",      emoji: '🐯', props: 'confidence and steady focus' },
  { name: 'Aquamarine',       emoji: '🌊', props: 'calm seas and clear speech' },
  { name: 'Garnet',           emoji: '❤️', props: 'passion and devotion' },
  { name: 'Fluorite',         emoji: '💜', props: 'focus and mental order' },
  { name: 'Sunstone',         emoji: '🌅', props: 'vitality and warmth' },
  { name: 'Jade',             emoji: '💚', props: 'harmony and gentle prosperity' },
  { name: 'Malachite',        emoji: '🌿', props: 'deep heart-healing and change' },
  { name: 'Smoky Quartz',     emoji: '🌫️', props: 'grounding and letting go' },
  { name: 'Opal',             emoji: '🌈', props: 'inspiration and emotional flow' },
  { name: 'Turquoise',        emoji: '🩵', props: 'protection and wholeness' },
];

export function crystalOfTheDay(d = new Date()) {
  const seed = d.getFullYear() * 372 + d.getMonth() * 31 + d.getDate();
  return CRYSTALS[seed % CRYSTALS.length];
}

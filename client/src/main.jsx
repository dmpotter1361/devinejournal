import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { GoogleOAuthProvider } from '@react-oauth/google';

// Fonts
import '@fontsource/cormorant-garamond/400.css';
import '@fontsource/cormorant-garamond/400-italic.css';
import '@fontsource/cormorant-garamond/600.css';
import '@fontsource/cinzel-decorative/400.css';
import '@fontsource/cinzel-decorative/700.css';
import '@fontsource/caveat/400.css';
import '@fontsource/caveat/600.css';
import '@fontsource/dancing-script/400.css';
import '@fontsource/indie-flower/400.css';
import '@fontsource/lora/400.css';
import '@fontsource/lora/400-italic.css';
import '@fontsource/nunito/400.css';

import './theme.css';
import App from './App';
import { applyTheme } from './themes';

const GOOGLE_CLIENT_ID = '900843330975-970qsohcbim8cmub4l8jdbdp1c5a1nse.apps.googleusercontent.com';

// Apply saved theme before first render to avoid flash
const savedTheme = localStorage.getItem('dj_theme') || 'midnight';
applyTheme(savedTheme);

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
      <App />
    </GoogleOAuthProvider>
  </StrictMode>
);

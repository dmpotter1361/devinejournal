import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useGoogleLogin } from '@react-oauth/google';
import { api, setToken, getToken, USER_KEY } from '../api';
import './SignIn.css';

export default function SignIn() {
  const nav = useNavigate();

  useEffect(() => {
    if (getToken()) nav('/timeline', { replace: true });
  }, [nav]);

  const login = useGoogleLogin({
    onSuccess: async ({ access_token }) => {
      try {
        const data = await api.googleAuth(access_token);
        setToken(data.access_token);
        localStorage.setItem(USER_KEY, JSON.stringify({ name: data.user_name, picture: data.user_picture }));
        nav('/timeline', { replace: true });
      } catch (err) {
        alert('Sign-in failed: ' + err.message);
      }
    },
    onError: (err) => alert('Google error: ' + (err.error_description || err.error)),
  });

  return (
    <div className="signin-page">
      <div className="signin-stars" aria-hidden="true">
        {[...Array(40)].map((_, i) => (
          <span key={i} className="signin-star" style={{
            left: `${(i * 37 + i * i * 7) % 100}%`,
            top: `${(i * 53 + i * 11) % 100}%`,
            animationDelay: `${(i * 0.4) % 3}s`,
            width: i % 3 === 0 ? '2px' : '1.5px',
            height: i % 3 === 0 ? '2px' : '1.5px',
          }} />
        ))}
      </div>
      <div className="signin-card">
        <div className="signin-moon">🌙</div>
        <h1 className="signin-title cinzel">DevineJournal</h1>
        <p className="signin-sub">Your sacred space to reflect, dream, and remember.</p>
        <button className="signin-google-btn" onClick={() => login()}>
          <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
            <path fill="#4285F4" d="M16.51 8H8.98v3h4.3c-.18 1-.74 1.48-1.6 2.04v2.01h2.6a7.8 7.8 0 0 0 2.38-5.88c0-.57-.05-.66-.15-1.18z"/>
            <path fill="#34A853" d="M8.98 17c2.16 0 3.97-.72 5.3-1.94l-2.6-2a4.8 4.8 0 0 1-7.18-2.54H1.83v2.07A8 8 0 0 0 8.98 17z"/>
            <path fill="#FBBC05" d="M4.5 10.52a4.8 4.8 0 0 1 0-3.04V5.41H1.83a8 8 0 0 0 0 7.18l2.67-2.07z"/>
            <path fill="#EA4335" d="M8.98 4.18c1.17 0 2.23.4 3.06 1.2l2.3-2.3A8 8 0 0 0 1.83 5.4L4.5 7.49a4.77 4.77 0 0 1 4.48-3.3z"/>
          </svg>
          Continue with Google
        </button>
        <p className="signin-note">Your journal is private to you.</p>
      </div>
    </div>
  );
}

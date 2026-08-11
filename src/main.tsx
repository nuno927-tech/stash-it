import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { applyTheme, prefersDark } from './lib/theme';
import './styles/base.css';

// Paint the right theme before React mounts, so a light-mode user never sees
// a dark flash. The stored choice replaces this a tick later if it differs.
applyTheme(prefersDark() ? 'dark' : 'light');

const root = document.getElementById('root');
if (!root) throw new Error('#root missing from index.html');

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

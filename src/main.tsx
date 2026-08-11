import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { watchInstallability } from './lib/install';
import { applyTheme, prefersDark } from './lib/theme';
import './styles/base.css';

// Match the device theme before React mounts so the app appears behind the
// splash in the right palette. The stored choice replaces this a tick later if
// it differs. The splash itself is in index.html and has its own light-mode
// rule, so it is already correct before this runs.
applyTheme(prefersDark() ? 'dark' : 'light');

// `beforeinstallprompt` fires early and exactly once. Miss it and there is no
// way to offer an in-app install button at all, so the listener goes up before
// React does; App re-reads the result once it's mounted.
watchInstallability(() => {});

const root = document.getElementById('root');
if (!root) throw new Error('#root missing from index.html');

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

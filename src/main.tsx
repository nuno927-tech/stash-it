import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { registerSW } from 'virtual:pwa-register';
import App from './App';
import { watchInstallability } from './lib/install';
import { applyTheme, prefersDark } from './lib/theme';
import './styles/base.css';

/*
  Keep the installed app on the current build.

  Nothing here used to register the worker at all — only the marketing page
  did, once, when someone happened to visit it. So an installed app would go on
  serving whatever bundle it had cached the day it was installed, and a fix
  shipped on Tuesday could still be missing on Friday. That is a miserable bug
  to chase, because everything looks correct in the source.

  `immediate` registers on load rather than after the window's load event, so
  the check happens on the launch you're already doing. With autoUpdate the new
  worker claims the page as soon as it's ready; `controllerchange` fires at that
  moment and the reload swaps the running code for the code it's now serving —
  once, guarded, because a reload loop here would be unrecoverable on a phone.
*/
if ('serviceWorker' in navigator) {
  let reloading = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloading) return;
    reloading = true;
    location.reload();
  });
  registerSW({ immediate: true });
}

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

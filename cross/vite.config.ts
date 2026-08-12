import { defineConfig } from 'vite';

export default defineConfig({
  // The app is served from a subfolder on GitHub Pages and from file:// inside
  // Electron, so every asset path has to be relative.
  base: './',
  build: { outDir: 'dist', emptyOutDir: true, target: 'es2022' },
});

import { defineConfig } from 'vite';
import { extensions, hbs, ember } from '@embroider/vite';
import { babel } from '@rollup/plugin-babel';

const unminified = process.env.OPENXPKI_UI_BUILD_UNMINIFIED == 1;

export default defineConfig({
  base: '', // emit relative asset paths (no leading slash) so htdocs can be served from any subpath
  build: {
    outDir: process.env.OPENXPKI_BUILD_OUTPUT_PATH ?? 'dist',
    emptyOutDir: true, // clean output ("dist") dir before storing new assets there
    minify: unminified ? false : 'esbuild',
    sourcemap: unminified ? 'inline' : false,
  },
  server: {
    host: '0.0.0.0',
    watch: {
      // The container dev server syncs source via rsync (1s intervals), so
      // inotify is not needed and often exhausted by host processes (VSCode etc.)
      usePolling: true,
    },
    proxy: {
      '^.*/cgi-bin/webui.fcgi': {
        target: process.env.DEV_SERVER_FORWARD_TO,
        secure: false,
      },
    },
  },
  plugins: [
    hbs(),
    ember(),
    babel({
      babelHelpers: 'runtime',
      extensions,
    }),
  ],
});

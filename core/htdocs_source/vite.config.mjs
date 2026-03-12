import { defineConfig } from 'vite';
import { extensions, classicEmberSupport, ember } from '@embroider/vite';
import { babel } from '@rollup/plugin-babel';

export default defineConfig({
  build: {
    outDir: process.env.OPENXPKI_BUILD_OUTPUT_PATH ?? 'dist',
  },
  server: {
    host: '0.0.0.0',
    proxy: {
      '/cgi-bin/webui.fcgi': {
        target: process.env.DEV_SERVER_FORWARD_TO,
        secure: false,
      },
    },
  },
  plugins: [
    classicEmberSupport(),
    ember(),
    // extra plugins here
    babel({
      babelHelpers: 'runtime',
      extensions,
    }),
  ],
});

import { defineConfig } from 'vite';
import { extensions, hbs, ember } from '@embroider/vite';
import { babel } from '@rollup/plugin-babel';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);

// @embroider/vite@1.6.1's embroider-resolver plugin calls emitFile() in its
// buildEnd hook, which Vite 6+ throws on during the dev-server dep-scan build.
// Guard it so buildEnd only runs for actual `vite build` invocations.
function fixEmbroiderResolverForVite6(plugins) {
  return plugins.map((p) => {
    if (p?.name !== 'embroider-resolver' || !p.buildEnd) return p;
    let serveMode = false;
    const origConfigResolved = p.configResolved;
    const origBuildEnd = p.buildEnd;
    return {
      ...p,
      configResolved(config) {
        serveMode = config.command === 'serve';
        origConfigResolved?.call(this, config);
      },
      async buildEnd(...args) {
        if (serveMode) return;
        return origBuildEnd.apply(this, args);
      },
    };
  });
}

const unminified = process.env.OPENXPKI_UI_BUILD_UNMINIFIED == 1;

export default defineConfig({
  base: '', // emit relative asset paths (no leading slash) so htdocs can be served from any subpath
  build: {
    outDir: process.env.OPENXPKI_BUILD_OUTPUT_PATH ?? 'dist',
    emptyOutDir: true, // clean output ("dist") dir before storing new assets there
    minify: unminified ? false : 'esbuild',
    sourcemap: unminified ? 'inline' : false,
  },
  // In the pure-Vite / no-classicEmberSupport build, `import { tracked } from
  // '@glimmer/tracking'` would resolve to the standalone npm package
  // @glimmer/tracking@1.1.2, which depends on @glimmer/validator@0.44.0.
  // ember-source@6.11 ships its own copy of @glimmer/validator@0.95.0 inside
  // dist/packages/@glimmer/validator/index.js (loaded via the embroider resolver
  // for all @glimmer/runtime, @glimmer/manager, etc. imports).  These two
  // validator instances have *separate* WeakMaps and revision counters, so
  // @tracked property mutations are invisible to Ember's renderer — no re-renders
  // ever fire.
  //
  // Fix: redirect @glimmer/tracking to ember-source's own bundled implementation
  // at dist/packages/@glimmer/tracking/index.js, which imports trackedData from
  // ../validator/index.js — the same file used by the rest of the runtime.
  // Rollup/Vite deduplicate by resolved path, so there is exactly one validator
  // instance and one shared tracking registry.
  //
  // The standalone @glimmer/tracking package can therefore be dropped from
  // package.json entirely.
  resolve: {
    alias: {
      '@glimmer/tracking': require.resolve('ember-source/@glimmer/tracking/index.js'),
    },
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
    ...fixEmbroiderResolverForVite6(ember()),
    babel({
      babelHelpers: 'runtime',
      extensions,
    }),
  ],
});

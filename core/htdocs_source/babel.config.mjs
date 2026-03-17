import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { templateCompatSupport, templateColocation } from '@embroider/compat/babel';
import { buildMacros } from '@embroider/macros/babel';

const { babelMacros } = buildMacros();

export default {
  plugins: [
    ...babelMacros,
    [
      'babel-plugin-ember-template-compilation',
      {
        transforms: [...templateCompatSupport()],
      },
    ],
    templateColocation(),
    [
      'module:decorator-transforms',
      {
        runtime: {
          import: fileURLToPath(
            import.meta.resolve('decorator-transforms/runtime-esm'),
          ),
        },
      },
    ],
    [
      '@babel/plugin-transform-runtime',
      {
        absoluteRuntime: dirname(fileURLToPath(import.meta.url)),
        useESModules: true,
        regenerator: false,
      },
    ],
  ],

  generatorOpts: {
    compact: false,
  },
};

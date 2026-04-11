// eslint.config.mjs
/**
 * Debugging:
 *   https://eslint.org/docs/latest/use/configure/debug
 *
 *   Print a file's calculated configuration:
 *     npx eslint --print-config path/to/file.js
 *
 *   Inspecting the config:
 *     npx eslint --inspect-config
 */

import globals from 'globals';
import js from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';

import emberPlugin from 'eslint-plugin-ember';
import emberParser from 'ember-eslint-parser';
import babelParser from '@babel/eslint-parser';
import qunit from 'eslint-plugin-qunit';
import n from 'eslint-plugin-n';
import prettierRecommended from 'eslint-plugin-prettier/recommended';

// Useful presets from plugins
const emberRecommended = emberPlugin.configs.recommended;
const emberRecommendedGjs = emberPlugin.configs['recommended-gjs'];
const emberRecommendedGts = emberPlugin.configs['recommended-gts'];

export default defineConfig([
  // Global ignores
  globalIgnores(['dist/', 'coverage/', 'tmp/', 'node_modules/', '!**/.*']),

  // Base JS rules (applies to everything JS-ish, will be refined by overrides below)
  js.configs.recommended,

  // General Ember JS/TS rules for classic files (.js, maybe .ts)
  {
    files: ['**/*.{js,ts}'],
    languageOptions: {
      parser: babelParser,
      parserOptions: {
        requireConfigFile: false,
        babelOptions: {
          configFile: false,
          plugins: [['@babel/plugin-proposal-decorators', { legacy: true }]],
        },
      },
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
      },
    },
    plugins: {
      ember: emberPlugin,
    },
    rules: {
      // Start from the plugin's recommended rules
      ...emberRecommended.rules,

      // Example tweaks:
      'no-console': 'warn',
      'ember/no-jquery': 'error',

      // Crashes with @babel/eslint-parser due to AST differences
      'ember/no-tracked-properties-from-args': 'off',
    },
  },

  // GJS files – first-class template components in JS
  {
    files: ['**/*.gjs'],
    languageOptions: {
      parser: emberParser,
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
      },
    },
    plugins: {
      ember: emberPlugin,
    },
    rules: {
      // Recommended Ember + GJS rules
      ...emberRecommended.rules,
      ...emberRecommendedGjs.rules,
    },
  },

  // GTS files – first-class template components in TS
  {
    files: ['**/*.gts'],
    languageOptions: {
      parser: emberParser,
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
      },
    },
    plugins: {
      ember: emberPlugin,
    },
    rules: {
      ...emberRecommended.rules,
      ...emberRecommendedGts.rules,
    },
  },

  // HBS templates – parsed by ember-eslint-parser as Handlebars
  {
    files: ['**/*.hbs'],
    languageOptions: {
      parser: emberParser,
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
      },
    },
    plugins: {
      ember: emberPlugin,
    },
    rules: {
      // Ember’s template-related rules live here too
      ...emberRecommended.rules,
    },
  },

  // Test files (QUnit)
  {
    files: ['tests/**/*-test.{js,gjs,gts,ts}'],
    plugins: {
      qunit,
      ember: emberPlugin,
    },
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.browser,
      },
    },
    rules: {
      ...qunit.configs.recommended.rules,
      ...emberRecommended.rules,
      // You can relax some Ember rules here if tests need it
    },
  },

  // Node CJS files
  {
    files: ['**/*.cjs', 'config/**/*.js', 'ember-cli-build.js'],
    plugins: {
      n,
    },
    languageOptions: {
      sourceType: 'script',
      ecmaVersion: 'latest',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      ...n.configs.recommended.rules,
    },
  },

  // Node ESM files
  {
    files: ['**/*.mjs'],
    plugins: {
      n,
    },
    languageOptions: {
      sourceType: 'module',
      ecmaVersion: 'latest',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      ...n.configs.recommended.rules,
    },
  },

  // Linter options
  {
    linterOptions: {
      reportUnusedDisableDirectives: 'error',
    },
  },

  // Prettier MUST be last so it disables conflicting stylistic rules
  prettierRecommended,
]);

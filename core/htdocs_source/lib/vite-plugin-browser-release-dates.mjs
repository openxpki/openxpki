/**
 * Vite plugin: extracts browser release dates from caniuse-lite at BUILD TIME
 * and exposes them as a small virtual module.
 *
 * This replaces `import lite from 'caniuse-lite'` (1.6 MB in-bundle) with a
 * ~5 kB JSON map of { browserName: { browser, release_date: { version: timestamp } } }.
 *
 * Only browsers listed in the `oldBrowser` check are included (see controller.js).
 */

import { createRequire } from 'module';

const VIRTUAL_ID = 'virtual:browser-release-dates';
const RESOLVED_ID = '\0' + VIRTUAL_ID;

// Browsers referenced by the oldBrowser getter (caniuse agent IDs)
const BROWSERS = [
  'edge', 'ios_saf', 'samsung', 'chrome', 'firefox',
  'op_mini', 'opera', 'ie', 'bb', 'android', 'safari',
  'and_chr', 'and_ff',
];

export default function browserReleaseDatesPlugin() {
  return {
    name: 'browser-release-dates',
    resolveId(id) {
      if (id === VIRTUAL_ID) return RESOLVED_ID;
    },
    load(id) {
      if (id !== RESOLVED_ID) return;

      const require = createRequire(import.meta.url);
      const lite = require('caniuse-lite');

      const agents = {};
      for (const name of BROWSERS) {
        const agent = lite.agents[name];
        if (!agent) continue;
        // Only keep versions that have a release_date (non-null)
        const dates = {};
        for (const [version, ts] of Object.entries(agent.release_date)) {
          if (ts != null) dates[version] = ts;
        }
        agents[name] = { browser: agent.browser, release_date: dates };
      }

      return `export default ${JSON.stringify(agents)};`;
    },
  };
}

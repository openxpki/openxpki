import {
  setupApplicationTest as upstreamSetupApplicationTest,
  setupRenderingTest as upstreamSetupRenderingTest,
  setupTest as upstreamSetupTest,
} from 'ember-qunit';
import MockOxiBackendService from './mock-backend';

// This file exists to provide wrappers around ember-qunit's
// test setup functions. This way, you can easily extend the setup that is
// needed per test type.

function setupApplicationTest(hooks, options) {
  upstreamSetupApplicationTest(hooks, options);

  hooks.beforeEach(function () {
    this.owner.register('service:oxi-backend', MockOxiBackendService);
  });
}

function setupRenderingTest(hooks, options) {
  upstreamSetupRenderingTest(hooks, options);

  // Additional setup for rendering tests can be done here.
}

function setupTest(hooks, options) {
  upstreamSetupTest(hooks, options);

  // Additional setup for unit tests can be done here.
}

export { setupApplicationTest, setupRenderingTest, setupTest };

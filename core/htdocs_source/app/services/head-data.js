import Service, { service } from '@ember/service';

/**
 * Exposes {@link module:service/oxi-config} to `app/templates/head.hbs`.
 *
 * Ember CLI auto-injects this service into `head.hbs`, where it is available
 * as `this.model`.
 *
 * @module service/head-data
 */
export default class HeadDataService extends Service {
    @service('oxi-config') config;
}

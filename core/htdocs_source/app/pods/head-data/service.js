import Service, { service } from '@ember/service';

/*
  This service is auto-injected into app/templates/head.hbs by Ember CLI.
  An instance of this service can be accessed via the 'model' attribute
  in app/templates/head.hbs.
*/
export default class HeadDataService extends Service {
    @service('oxi-config') config;
}

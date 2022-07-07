import Service, { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
// import { service } from '@ember/service';

export default class HeadDataService extends Service {
    @service('oxi-config') config;
}

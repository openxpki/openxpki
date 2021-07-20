import Service, { inject } from '@ember/service';
import { tracked } from '@glimmer/tracking';
// import { inject } from '@ember/service';

export default class HeadDataService extends Service {
    @inject('oxi-config') config;
}

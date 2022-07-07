import Component from '@glimmer/component';
import { service } from '@ember/service';

export default class ApplicationFooter extends Component {
    @service('oxi-config') config;
}

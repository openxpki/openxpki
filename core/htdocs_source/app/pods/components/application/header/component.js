import Component from '@glimmer/component';
import { service } from '@ember/service';

export default class ApplicationHeader extends Component {
    @service('oxi-config') config;
    @service('oxi-content') content;
}

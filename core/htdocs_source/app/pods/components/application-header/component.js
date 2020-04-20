import Component from '@glimmer/component';
import { inject as service } from '@ember/service';

export default class OxiApplicationHeader extends Component {
    @service('oxi-config') config;
}

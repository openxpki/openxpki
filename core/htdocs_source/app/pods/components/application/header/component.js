import Component from '@glimmer/component';
import { inject } from '@ember/service';

export default class ApplicationHeader extends Component {
    @inject('oxi-config') config;
    @inject('oxi-content') content;
}

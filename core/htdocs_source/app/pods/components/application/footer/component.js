import Component from '@glimmer/component';
import { inject } from '@ember/service';

export default class ApplicationFooter extends Component {
    @inject('oxi-config') config;
}

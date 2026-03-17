// Injects page title and optional custom CSS into document.head.
// Replaces ember-cli-head (HeadLayout + HeadContent + head-data service).
import Component from '@glimmer/component';
import { service } from '@ember/service';

export default class HeadLayout extends Component {
    @service('oxi-config') config;

    get headElement() {
        return this.args.headElement || document.head;
    }
}

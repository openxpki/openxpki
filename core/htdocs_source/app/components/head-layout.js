import Component from '@glimmer/component';
import { service } from '@ember/service';

/**
 * Injects page title and optional custom CSS into `document.head`.
 * Replaces ember-cli-head (HeadLayout + HeadContent + head-data service).
 * All content is sourced from the {@link service/oxi-config} service; no arguments are required.
 *
 * @param { Element } [headElement] - Target DOM element to render into. Defaults to `document.head`.
 *
 * @class HeadLayout
 * @extends Component
 */
export default class HeadLayout extends Component {
    @service('oxi-config') config;

    get headElement() {
        return this.args.headElement || document.head;
    }
}

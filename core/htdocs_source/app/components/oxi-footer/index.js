import Component from '@glimmer/component';
import { service } from '@ember/service';

/**
 * Application footer bar. Renders a custom HTML footer from `oxi-config.footer`
 * or falls back to the default copyright notice.
 *
 * Accepts block content via `{{yield}}`.
 *
 * @class OxiFooter
 * @extends Component
 */
export default class ApplicationFooter extends Component {
    @service('oxi-config') config;
}

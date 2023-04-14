import Component from '@glimmer/component';
import { action } from '@ember/object';
import { service } from '@ember/service';

/**
 * Show a link to an OpenXPKI page.
 *
 * ```html
 * <OxiBase::Formatted::Link @spec={{spec}} @class="oxi-formatted-link" />
 * ```
 *
 * @param { hash } spec - link information
 * ```javascript
 * {
 *     label: 'Click me',
 *     tooltip: 'See!',
 *     page: 'workflow!load!wf_id!299007',
 *     target: 'https://www.openxpki.org',
 * }
 * ```
 * @class OxiBase::Formatted::Link
 */
export default class OxiFormattedLinkComponent extends Component {
    @service('oxi-content') content;

    @action
    internalLinkClick(event) {
        let target = this.args.spec.target || "popup";

        // ignore links with _blank target
        if (target === "_blank") return true;

        // perform AJAX request instead of opening URL
        event.stopPropagation();
        event.preventDefault();
        this.content.updateRequest({
            page: this.args.spec.page,
            target: target,
        });
    }
}

import Component from '@glimmer/component';
import { action } from '@ember/object';
import { service } from '@ember/service';
import Link from 'openxpki/data/link'

/**
 * Show a link to an OpenXPKI page.
 *
 * ```html
 * <OxiBase::Formatted::Link @spec={{spec}} @class="oxi-formatted-link" />
 * ```
 *
 * @param { hash | Link } spec - link definition
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
    @service('oxi-content') content

    get link() {
        return Link.fromHash({
            ...this.args.spec,
            target: this.args.spec.target || 'popup',
        })
    }
}

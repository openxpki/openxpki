import Component from '@glimmer/component'
import { service } from '@ember/service'
import Link from 'openxpki/data/link'

/**
 * Show a link to an OpenXPKI page.
 *
 * ```html
 * <OxiBase::Formatted::Link @spec={{spec}} @class="oxi-formatted-link" />
 * ```
 *
 * @param { object | Link } spec - Link definition.
 * @param { string } spec.label - Link text.
 * @param { string } [spec.tooltip] - Tooltip shown on hover.
 * @param { string } spec.page - OpenXPKI page to open.
 * @param { string } [spec.target] - Link target; defaults to `'popup'`.
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

    /**
     * Returns `@spec` as a {@link Link} instance, defaulting `target` to `"popup"`.
     * @memberOf OxiBase::Formatted::Link
     */
    get link() {
        return Link.fromHash({
            ...this.args.spec,
            target: this.args.spec.target || 'popup',
        })
    }
}

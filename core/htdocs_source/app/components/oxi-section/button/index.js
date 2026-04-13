import Component from '@glimmer/component'

/**
 * Render a single clickable button tile.
 *
 * ```html
 * <OxiSection::Button @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition (passed through to {@link OxiBase::Button}).
 * @param { string } def.label - Button label text.
 * @param { string } [def.image] - URL of an image shown above the label.
 * @param { string } [def.tooltip] - Tooltip text.
 * @param { string } [def.format] - Button style override. Default: `'tile'`
 * @param { boolean } [def.disabled] - Disable the button.
 * @param { object } [def.confirm] - Confirmation popup config (`label`, `description`,
 *   `confirm_label`, `cancel_label`).
 * @param { string } [def.href] - Renders as `<a href>` link.
 * @param { string } [def.target] - Link target (only with `href`).
 * @param { string } [def.page] - OpenXPKI page to load on click.
 * @param { string } [def.action] - OpenXPKI action to call on click.
 * @param { object } [def.action_params] - Additional parameters sent with `action`.
 *
 * @class OxiSection::Button
 * @extends Component
 */
export default class OxiSectionButtonComponent extends Component {
    /**
     * Returns the button definition with `format` defaulted to `"tile"`.
     * @memberOf OxiSection::Button
     */
    get button() {
        return {
            format: 'tile',
            ...this.args.def,
        }
    }

    /**
     * Returns the resolved icon CSS class string, expanding `glyphicon-*` / `bi-*` prefixes,
     * or `null` when no icon is configured.
     * @memberOf OxiSection::Button
     */
    get icon() {
        let icon = this.args.def.icon
        if (! icon) return null
        if (icon.match(/^glyphicon-/)) return `glyphicon ${icon}`
        if (icon.match(/^bi-/)) return `bi ${icon}`
        return icon
    }
}

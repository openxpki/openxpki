import Component from '@glimmer/component'

/**
 * Render a single clickable button tile.
 *
 * ```html
 * <OxiSection::Button @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition (passed through to {@link OxiBase::Button}):
 *   - `label` { string } - Button label text
 *   - `image` { string } - Optional URL of an image shown above the label
 *   - `tooltip` { string } - Tooltip text
 *   - `format` { string } - Button style override (default: `'tile'`)
 *   - `disabled` { boolean } - Disable the button
 *   - `confirm` { object } - Confirmation popup config (`label`, `description`,
 *     `confirm_label`, `cancel_label`)
 *   - `href` { string } - Renders as `<a href>` link
 *   - `target` { string } - Link target (only with `href`)
 *   - `page` { string } - OpenXPKI page to load on click
 *   - `action` { string } - OpenXPKI action to call on click
 *   - `action_params` { object } - Additional parameters sent with `action`
 *
 * @class OxiSection::Button
 * @extends Component
 */
export default class OxiSectionButtonComponent extends Component {
    get button() {
        return {
            format: 'tile',
            ...this.args.def,
        }
    }
}

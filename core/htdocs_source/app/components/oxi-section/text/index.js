import Component from '@glimmer/component'

/**
 * Render a block of HTML text, optionally followed by buttons.
 *
 * ```html
 * <OxiSection::Text @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition:
 *   - `buttons` { array } - Optional list of button descriptors passed to
 *     {@link OxiBase::ButtonContainer}.
 *   - `label` { string } - Section heading (rendered by the parent
 *     {@link OxiSection} wrapper, not by this component directly).
 *   - `description` { string } - Subheading shown below the label (also
 *     rendered by the parent {@link OxiSection} wrapper).
 *
 * @class OxiSection::Text
 * @extends Component
 */
export default class OxiSectionTextComponent extends Component {}

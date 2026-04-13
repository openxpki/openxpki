import Component from '@glimmer/component'

/**
 * Render a block of HTML text, optionally followed by buttons.
 *
 * ```html
 * <OxiSection::Text @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition.
 * @param { array } [def.buttons] - List of button descriptors passed to {@link OxiBase::ButtonContainer}.
 * @param { string } [def.label] - Section heading (rendered by the parent {@link OxiSection} wrapper).
 * @param { string } [def.description] - Subheading shown below the label (rendered by the parent {@link OxiSection} wrapper).
 *
 * @class OxiSection::Text
 * @extends Component
 */
export default class OxiSectionTextComponent extends Component {}

import Component from '@glimmer/component';

/**
 * Render a chart section, delegating to {@link OxiBase::Chart}.
 *
 * ```html
 * <OxiSection::Chart @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition.
 * @param { array } def.data - Chart data rows. Each row is an array where the first
 *   element is the X value and the remaining elements are Y values per series:
 *   `[ [x1, a1, b1, ...], [x2, a2, b2, ...], ... ]`
 * @param { string } [def.className] - Extra CSS class added to the chart root element.
 *   Mapped to `options.cssClass` before forwarding. Default: `null`
 * @param { object } [def.options] - Display options forwarded to {@link OxiBase::Chart}
 *   (see that component for the full list of supported keys).
 *
 * @class OxiSection::Chart
 * @extends Component
 */
export default class OxiSectionChartComponent extends Component {
    /**
     * Returns the merged options hash, mapping `def.className` to `options.cssClass`
     * for compatibility with {@link OxiBase::Chart}.
     * @memberOf OxiSection::Chart
     */
    get options() {
        let add = {};
        if (this.args.def?.className) {
            add.cssClass = this.args.def.className
        }
        return {
            ...this.args.def?.options,
            ...add,
        }
    }
}

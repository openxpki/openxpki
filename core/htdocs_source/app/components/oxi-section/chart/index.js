import Component from '@glimmer/component';

/**
 * Draws a chart.
 *
 * @class OxiSection::Chart
 * @extends Component
 */
export default class OxiSectionKeyvalueComponent extends Component {
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

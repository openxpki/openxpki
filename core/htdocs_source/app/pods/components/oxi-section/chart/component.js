import Component from '@glimmer/component';
import { computed } from '@ember/object';

/**
 * Draws a chart.
 *
 * @module component/oxi-section/chart
 */
export default class OxiSectionKeyvalueComponent extends Component {
    @computed("args.def.options")
    get options() {
        let add = {};
        if (this.args.def.className) {
            add.cssClass = this.args.def.className
        }
        return {
            ...this.args.def.options,
            ...add,
        }
    }
}

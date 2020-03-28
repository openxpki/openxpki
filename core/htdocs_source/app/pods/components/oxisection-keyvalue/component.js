import Component from '@glimmer/component';
import { computed } from '@ember/object';
import types from "../oxivalue-format/types";

export default class OxisectionKeyvalueComponent extends Component {
    @computed("args.content.content.data")
    get items() {
        let items = this.args.content.content.data || [];
        for (const i of items) {
            if (i.format === 'head') { i.isHead = 1 }
        }
        return items.filter(item => types[item.format || 'text'](item.value) !== '');
    }
}

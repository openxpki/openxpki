import Component from '@glimmer/component';
import { computed } from '@ember/object';

export default class OxiButtonContainerComponent extends Component {
    @computed("args.buttons.@each.description")
    get hasDescription() {
        let ref;
        return (ref = this.args.buttons) != null ? ref.isAny("description") : void 0;
    }
}

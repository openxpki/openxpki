import Component from '@glimmer/component';
import { action } from '@ember/object';

export default class BsButton extends Component {
    get typeClass() {
        return this.args.type ? `btn-${this.args.type}` : '';
    }

    @action
    handleClick(event) {
        this.args.onClick?.(event);
    }
}

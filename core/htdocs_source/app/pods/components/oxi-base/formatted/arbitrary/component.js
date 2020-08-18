import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';

export default class OxiFormattedArbitraryComponent extends Component {
    @tracked detailsOpen = false;

    get type() {
        return typeof this.args.value;
    }

    get isString() {
        return (this.type === 'string' || this.type === 'undefined' || this.type === 'null');
    }

    get asJSON() {
        return JSON.stringify(this.args.value, null, 2);
    }

    @action
    toggleDetails() {
        this.detailsOpen = !this.detailsOpen;
    }
}

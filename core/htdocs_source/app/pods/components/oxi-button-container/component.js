import Component from '@glimmer/component';
import { computed } from '@ember/object';

export default class OxiButtonContainerComponent extends Component {
    get buttonGroups() {
        let currentGroup = [];
        let groups = [currentGroup];
        let buttons = this.args.buttons;

        for (const btn of buttons) {
            if (btn.break_before) { currentGroup = []; groups.push(currentGroup) }
            currentGroup.push(btn);
            if (btn.break_after)  { currentGroup = []; groups.push(currentGroup) }
        }
        return groups;
    }

    @computed("args.buttons.@each.description")
    get hasDescription() {
        let ref;
        return (ref = this.args.buttons) != null ? ref.isAny("description") : void 0;
    }
}

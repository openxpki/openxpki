import Component from '@glimmer/component';

/**
 * Shows buttons as a group.
 *
 * ```html
 * <OxiBase::ButtonContainer @buttons={{data}} @buttonClick={{myFunc}}/>
 * ```
 *
 * @param { array } buttons - List of button definitions to be passed to {@link module:oxi-base/button}
 * If a button definition hash contains the attributes `break_before` or
 * `break_after` then a line break will be inserted before or after that
 * button.
 * @module component/oxi-base/button-container
 */
export default class OxiButtonContainerComponent extends Component {
    get buttonGroups() {
        let buttons = this.args.buttons || [];
        let groups = [];
        let currentGroup = [];

        for (const btn of buttons) {
            if (btn.break_before) { groups.push(currentGroup); currentGroup = [] }
            currentGroup.push(btn);
            if (btn.break_after)  { groups.push(currentGroup); currentGroup = [] }
        }

        groups.push(currentGroup);

        return groups;
    }

    get hasDescription() {
        let ref;
        return (ref = this.args.buttons) != null ? ref.isAny("description") : void 0;
    }
}

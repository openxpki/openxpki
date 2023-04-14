import Component from '@glimmer/component'
import ContainerButton from 'openxpki/data/container-button'

/**
 * Shows buttons as a group.
 *
 * ```html
 * <OxiBase::ButtonContainer @buttons={{data}}/>
 * ```
 *
 * @param { array } buttons - List of button definitions (hash or
 * {@link ContainerButton} to be passed to {@link OxiBase::Button}.
 * If a button definition contains the attributes `break_before` or
 * `break_after` then a line break will be inserted before or after that
 * button.
 * @class OxiBase::ButtonContainer
 * @extends Component
 */
export default class OxiButtonContainerComponent extends Component {
    get buttons() {
        let btns = this.args.buttons || []
        return btns.map(def => ContainerButton.fromHash(def))
    }

    get buttonGroups() {
        let groups = []
        let currentGroup = []

        for (const btn of this.buttons) {
            if (btn.break_before) { groups.push(currentGroup); currentGroup = [] }
            currentGroup.push(btn)
            if (btn.break_after)  { groups.push(currentGroup); currentGroup = [] }
        }

        groups.push(currentGroup)

        return groups
    }

    get hasDescription() {
        if (!this.buttons) { return false }
        return this.buttons.some(i => i.description)
    }
}

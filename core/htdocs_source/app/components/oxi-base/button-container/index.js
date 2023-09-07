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
    buttons
    buttonGroups

    constructor() {
        super(...arguments)

        // buttons
        let btns = this.args.buttons || []
        this.buttons = btns.map(def => ContainerButton.fromHash(def))

        // button groups
        this.buttonGroups = []
        let currentGroup = []
        for (const btn of this.buttons) {
            if (btn.break_before) { this.buttonGroups.push(currentGroup); currentGroup = [] }
            currentGroup.push(btn)
            if (btn.break_after)  { this.buttonGroups.push(currentGroup); currentGroup = [] }
        }
        this.buttonGroups.push(currentGroup)
    }

    get hasDescription() {
        if (!this.buttons) { return false }
        return this.buttons.some(i => i.description)
    }

    get hasButtons() {
        return this.buttons.length > 0
    }
}

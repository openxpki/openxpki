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
    buttons = []
    maxButtonsPerRow = 4

    constructor() {
        super(...arguments)

        let addEmptyButton = () => this.buttons.push(ContainerButton.fromHash({ empty: true }))

        let buttons = (this.args.buttons || []).map(def => ContainerButton.fromHash(def))
        let buttonsPerRow = 0

        // button groups
        for (const btn of buttons) {
            if (btn.break_before) { addEmptyButton(); buttonsPerRow = 0 }
            this.buttons.push(btn)
            if (++buttonsPerRow > this.maxButtonsPerRow) this.maxButtonsPerRow = buttonsPerRow
            if (btn.break_after) { addEmptyButton(); buttonsPerRow = 0 }
        }

        if (this.maxButtonsPerRow > 6) this.maxButtonsPerRow = 6
    }

    get hasDescription() {
        if (!this.buttons) { return false }
        return this.buttons.some(i => i.description)
    }

    get hasButtons() {
        return this.buttons.length > 0
    }
}

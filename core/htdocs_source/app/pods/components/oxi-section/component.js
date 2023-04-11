import Component from '@glimmer/component'
import { action } from "@ember/object"

export default class OxiSectionComponent extends Component {
    get type() {
        return `oxi-section/${this.args.content.type}`;
    }

    get sectionData() {
        return {
            ...this.args.content?.content,
            // map some inconsistently placed properties into the section data
            action:     this.args.content?.action,       // used by oxi-section/form
            reset:      this.args.content?.reset,        // used by oxi-section/form
            className:  this.args.content?.className,    // used by oxi-section/grid
        }
    }

    @action
    initialized() {
        if (this.args.onInit) this.args.onInit();
    }
}

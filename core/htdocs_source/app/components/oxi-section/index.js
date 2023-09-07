import Component from '@glimmer/component'
import { action } from '@ember/object'
import { importSync } from '@embroider/macros'
import { ensureSafeComponent } from '@embroider/util'
import { debug } from '@ember/debug'

export default class OxiSectionComponent extends Component {
    get sectionComponent() {
        debug(`oxi-section: importing ./${this.args.content.type}`)
        let module = importSync(`./${this.args.content.type}`)
        return ensureSafeComponent(module.default, this)
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

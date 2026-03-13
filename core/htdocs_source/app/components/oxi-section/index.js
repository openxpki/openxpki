import Component from '@glimmer/component'
import { action } from '@ember/object'
import { debug } from '@ember/debug'

const sectionModules = Object.fromEntries(
    Object.entries(import.meta.glob('./*/index.js', { eager: true }))
        .map(([path, mod]) => [path.replace(/^\.\/(.+)\/index\..+$/, '$1'), mod])
)

export default class OxiSectionComponent extends Component {
    get sectionComponent() {
        debug(`oxi-section: importing ./${this.args.content.type}`)
        return sectionModules[this.args.content.type]?.default
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

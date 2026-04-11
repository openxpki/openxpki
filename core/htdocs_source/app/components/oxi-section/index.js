import Component from '@glimmer/component'
import { action } from '@ember/object'
import { debug } from '@ember/debug'

/**
 * Universal section dispatcher - renders a single content section by
 * dynamically loading the sub-component that matches `@content.type`.
 *
 * ```html
 * <OxiSection @content={{this.section}} @meta={{this.meta}} @onInit={{this.onInit}} />
 * ```
 *
 * @param { object } content - Section descriptor object:
 *   - `type` { string } - Section type key, e.g. `'keyvalue'`, `'form'`, `'grid'`,
 *     `'button'`, `'text'`, `'chart'`, `'cards'`, `'tiles'`. Determines which
 *     sub-component is loaded.
 *   - `content` { object } - Data passed to the sub-component as `@def`. May
 *     contain a `label` and `description` shown as heading/subheading (except
 *     for `type: 'button'` where the label lives on the button itself).
 *   - `action` { string } - Form submit action (forwarded to `oxi-section/form`).
 *   - `reset` { string } - Form reset action (forwarded to `oxi-section/form`).
 *   - `className` { string } - Extra CSS class (forwarded to `oxi-section/grid`).
 *   - `compact` { boolean } - Reduce padding/margin for embedded use.
 * @param { object } meta - Rendering metadata provided by the parent page:
 *   - `renderAsCard` { boolean } - Wrap the section in a Bootstrap card.
 *   - `isInfoBox` { boolean } - Suppress the left margin indent.
 * @param { function } [onInit] - Optional callback invoked once the section
 *   DOM element has been inserted (via the `on-init` modifier).
 *
 * @class OxiSection
 * @extends Component
 */

const sectionModules = Object.fromEntries(
    Object.entries(import.meta.glob('./*/index.js', { eager: true }))
        .map(([path, mod]) => [path.replace(/^\.\/(.+)\/index\..+$/, '$1'), mod])
)

export default class OxiSectionComponent extends Component {
    get sectionComponent() {
        debug(`oxi-section: importing ./${this.args.content.type}`)
        return sectionModules[this.args.content.type]?.default
    }

    get data() {
        return {
            ...this.args.content?.content,
            // map some inconsistently placed properties into the section data
            action:     this.args.content?.action,       // used by oxi-section/form
            reset:      this.args.content?.reset,        // used by oxi-section/form
            className:  this.args.content?.className,    // used by oxi-section/grid
        }
    }

    get meta() {
        return {
            ...(this.args.meta ?? {}),
            isCompact: this.args.content?.compact ? true : false,
        }
    }

    get label() {
        // Button labels are on the button, not above
        return this.args.content.type === 'button'
            ? null
            : this.args.content?.content?.label
    }

    @action
    initialized() {
        if (this.args.onInit) this.args.onInit();
    }
}

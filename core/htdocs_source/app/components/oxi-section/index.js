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
 * @param { object } content - Section descriptor object.
 * @param { string } content.type - Section type key, e.g. `'keyvalue'`, `'form'`, `'grid'`,
 *   `'button'`, `'text'`, `'chart'`, `'cards'`, `'tiles'`. Determines which sub-component is loaded.
 * @param { object } content.content - Data passed to the sub-component as `@def`. May
 *   contain a `label`, `description` and `footer` shown as heading/subheading/footer text (except
 *   for `type: 'button'` where the description lives on the button itself).
 * @param { string } [content.action] - Form submit action (forwarded to `oxi-section/form`).
 * @param { string } [content.reset] - Form reset action (forwarded to `oxi-section/form`).
 * @param { string } [content.className] - Extra CSS class (forwarded to `oxi-section/grid`).
 * @param { boolean } [content.compact] - Reduce padding/margin for embedded use.
 * @param { object } [meta] - Rendering metadata provided by the parent page.
 * @param { boolean } [meta.renderAsCard] - Wrap the section in a Bootstrap card.
 * @param { boolean } [meta.isInfoBox] - Suppress the left margin indent.
 * @param { function } [onInit] - Callback invoked once the section DOM element has been inserted
 *   (via the `on-init` modifier).
 *
 * @class OxiSection
 * @extends Component
 */

const sectionModules = Object.fromEntries(
    Object.entries(import.meta.glob('./*/index.js', { eager: true }))
        .map(([path, mod]) => [path.replace(/^\.\/(.+)\/index\..+$/, '$1'), mod])
)

export default class OxiSectionComponent extends Component {
    /**
     * Returns the resolved sub-component class for `content.type`, or `undefined`
     * when the type is unknown.
     * @memberOf OxiSection
     */
    get sectionComponent() {
        debug(`oxi-section: importing ./${this.args.content.type}`)
        return sectionModules[this.args.content.type]?.default
    }

    /**
     * Returns the section content merged with top-level section properties
     * (`action`, `reset`, `className`) that sub-components expect inside `@def`.
     * @memberOf OxiSection
     */
    get data() {
        return {
            ...this.args.content?.content,
            // map some inconsistently placed properties into the section data
            action:     this.args.content?.action,       // used by oxi-section/form
            reset:      this.args.content?.reset,        // used by oxi-section/form
            className:  this.args.content?.className,    // used by oxi-section/grid
        }
    }

    /**
     * Returns the merged metadata object, adding `isCompact` derived from `content.compact`.
     * @memberOf OxiSection
     */
    get meta() {
        return {
            ...(this.args.meta ?? {}),
            isCompact: this.args.content?.compact ? true : false,
        }
    }

    /**
     * Returns the section description, or `null` for `type: "button"` sections
     * where the description lives on the button itself.
     * @memberOf OxiSection
     */
    get description() {
        // Button labels are on the button, not above
        return this.args.content.type === 'button'
            ? null
            : this.args.content?.content?.description
    }

    /**
     * Invokes `@onInit` once after the section element has been inserted into the DOM.
     * @memberOf OxiSection
     */
    @action
    initialized() {
        if (this.args.onInit) this.args.onInit();
    }
}

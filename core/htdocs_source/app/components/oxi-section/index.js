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
        debug(`oxi-section: importing ./${this.args.def.type}`)
        return sectionModules[this.args.def.type]?.default
    }

    /**
     * Returns the section content merged with top-level section properties
     * (`action`, `reset`) that sub-components expect inside `@def`.
     * @memberOf OxiSection
     */
    get data() {
        return {
            ...this.args.def?.content,
            // Button labels are on the button, not within the common section component
            ...(this.args.def.type === 'button' ? {
                description: this.args.def?.description ?? this.args.def?.content?.description,
            } : {}),
            // Legacy compatibility to some inconsistently placed properties
            ...(this.args.def.type === 'form' ? {
                action: this.args.def?.content?.action ?? this.args.def?.action,
                reset:  this.args.def?.content?.reset ?? this.args.def?.reset,
            } : {}),
        }
    }

    /**
     * Returns the merged metadata object, adding `isCompact` derived from `content.compact`.
     * @memberOf OxiSection
     */
    get meta() {
        return {
            ...(this.args.meta ?? {}),
            isCompact: this.args.def?.compact ? true : false,
        }
    }

    /**
     * Returns the section label.
     * @memberOf OxiSection
     */
    get label() {
        return this.args.def?.label
            ?? this.args.def?.content?.label;
    }

    /**
     * Returns the section description, or `null` for `type: "button"` sections
     * where the description is the button label.
     * @memberOf OxiSection
     */
    get description() {
        // Button descriptions are on the button, not above
        return this.args.def.type !== 'button' ? (
              this.args.def?.description
           ?? this.args.def?.content?.description
           ) : null
    }

    /**
     * Returns the section footer.
     * @memberOf OxiSection
     */
    get footer() {
        return this.args.def?.footer
            ?? this.args.def?.content?.footer;
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

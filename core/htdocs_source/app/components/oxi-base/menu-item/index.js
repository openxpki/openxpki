import Component from '@glimmer/component'
import { action } from '@ember/object'
import { service } from '@ember/service'

/**
 * Shows a navigation bar menu item.
 *
 * ```html
 * <OxiBase::MenuItem
 *   @spec={{entry}}
 *   @isSubmenu={{true}}
 *   @onClick={{this.closeDropdown}}
 * />
 * ```
 *
 * @param { hash } spec - menu item specification:
 * @param { string } spec.label - display text for the menu item
 * @param { string } [spec.page] - internal OpenXPKI page name to navigate to
 * @param { string } [spec.url] - external URL to open (used when `page` is not set)
 * @param { string } [spec.icon] - icon class; prefix `glyphicon-` or `bi-` is
 *   auto-expanded to `glyphicon <icon>` / `bi <icon>` respectively
 * @param { boolean } [spec.active] - marks the item as the currently active page
 * @param { Array } [spec.entries] - if present the item has sub-entries and clicking
 *   it only triggers `@onClick` (no navigation)
 * @param { boolean } [isSubmenu] - when true, `aria-current` is set to `"true"` instead
 *   of `"page"` for active items
 * @param { function } [onClick] - callback invoked before navigation (e.g. to close a
 *   dropdown); receives no arguments
 * @class OxiBase::MenuItem
 */
export default class OxiMenuItemComponent extends Component {
    @service('oxi-content') content
    @service router;

    /**
     * Returns the `href` for the anchor element: the Ember route URL for `spec.page`,
     * `spec.url` for external links, or `"#"` for sub-menu parents.
     * @memberOf OxiBase::MenuItem
     */
    get href() {
        if (this.args.spec.entries) return "#"
        if (this.args.spec.page) return this.router.urlFor("openxpki", this.args.spec.page);
        if (this.args.spec.url) return this.args.spec.url
        return "#"
    }

    /**
     * Returns the resolved icon CSS class string, expanding `glyphicon-*` and `bi-*`
     * prefixes to their full class pairs, or `null` when no icon is configured.
     * @memberOf OxiBase::MenuItem
     */
    get icon() {
        let icon = this.args.spec.icon
        if (! icon) return null
        if (icon.match(/^glyphicon-/)) return `glyphicon ${icon}`
        if (icon.match(/^bi-/)) return `bi ${icon}`
        return icon
    }

    /**
     * Handles a click on the menu item: navigates to `spec.page`, opens `spec.url`,
     * or invokes `@onClick` for sub-menu parents.
     * @memberOf OxiBase::MenuItem
     */
    @action
    openTarget(event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        if (this.args.spec.entries) return this.#callBeforeNav()
        if (this.args.spec.page) return this.#navigateTo(this.args.spec.page)
        if (this.args.spec.url) return this.#callUrl(this.args.spec.url)
        return this.#callBeforeNav()
    }

    // We don't use <ddm.LinkTo> but our own method to navigate to target page.
    // This way we can force Ember to do a transition even if the new page is
    // the same page as before by setting parameter "force" a timestamp.
    #navigateTo(page, event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        this.#callBeforeNav()
        this.content.openPage({
            name: page,
            target: this.content.TARGET.TOP,
            force: true,
            params: { trigger: 'nav' },
        })
    }

    #callUrl(url, event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        this.#callBeforeNav()
        window.open(url, '_self')
    }

    #callBeforeNav() {
        let onClick = this.args.onClick
        if (typeof onClick === 'undefined' || onClick === null) return
        if (typeof onClick !== 'function') {
            /* eslint-disable-next-line no-console */
            console.error("<OxiBase::MenuItem>: Wrong type parameter type for @onClick. Expected: function, given: " + (typeof this.args.onClick))
            return
        }
        onClick()
    }
}

import Component from '@glimmer/component'
import { action } from '@ember/object'
import { service } from '@ember/service'

/**
 * Shows a navigation bar menu item.
 *
 * ```html
 * <OxiBase::MenuItem
 *   @spec={{entry}}
 *   @afterClick={{this.function}}
 * />
 * ```
 *
 * @param { hash } spec - menu item specification:
 * ```javascript
 * { label: 1, page: "Major", url, icon, entries },
 * ```
 * @param { callback } afterClick - function to run after the menu item was clicked (usually a function to close a dropdown)
 * @class OxiBase::MenuItem
 */
export default class OxiMenuItemComponent extends Component {
    @service('oxi-content') content

    // We don't use <ddm.LinkTo> but our own method to navigate to target page.
    // This way we can force Ember to do a transition even if the new page is
    // the same page as before by setting parameter "force" a timestamp.
    @action
    navigateTo(page, event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        this.#callBeforeNav()
        this.content.openPage({
            name: page,
            target: this.content.TARGET.TOP,
            force: true,
            params: { trigger: 'nav' },
        })
    }

    @action
    callUrl(url, event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        this.#callBeforeNav()
        window.open(url, '_self')
    }

    #callBeforeNav() {
        let beforeNav = this.args.beforeNav
        if (typeof beforeNav === 'undefined' && beforeNav === null) return
        if (typeof beforeNav !== 'function') {
            /* eslint-disable-next-line no-console */
            console.error("<OxiBase::MenuItem>: Wrong type parameter type for @beforeNav. Expected: function, given: " + (typeof this.args.beforeNav))
            return
        }
        beforeNav()
    }
}

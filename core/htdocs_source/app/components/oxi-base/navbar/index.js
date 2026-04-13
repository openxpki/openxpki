import Component from '@glimmer/component'
import { action } from '@ember/object'
import { tracked } from '@glimmer/tracking'

/**
 * Shows a navigation bar.
 *
 * ```html
 * <OxiBase::Navbar
 *   @items={{entries}}
 * />
 * ```
 *
 * @param { array } items - List of menu item specification hashes passed to {@link OxiBase::MenuItem}
 *   (see that component for the full set of supported keys):
 * ```javascript
 * [
 *   { label: "Home", page: "welcome!home", icon: "bi-home" },
 *   { label: "Actions", icon: "", entries: [ ... ] },
 * ]
 * ```
 * @class OxiBase::Navbar
 */
export default class OxiNavbarComponent extends Component {
    @tracked isCollapsed = true
    @tracked currentlyOpenDropdown

    /**
     * Returns the CSS classes for a top-level navbar item. Adds a left separator
     * border for every item after the first.
     * @memberOf OxiBase::Navbar
     */
    @action
    getRootItemClasses(index) {
        let classes = "py-1 ps-2 px-lg-3"
        if (index != 0) {
            classes += " border-start border-1 oxi-navbar-separator"
        }
        return classes
    }

    /**
     * Marks the dropdown at `index` as open.
     * @memberOf OxiBase::Navbar
     */
    @action
    openDropdown(index) {
        this.currentlyOpenDropdown = index
    }

    /**
     * Closes the open dropdown, unless the new focus target is a child of the same
     * dropdown (prevents the dropdown from closing when moving between its items).
     * @memberOf OxiBase::Navbar
     */
    @action
    closeDropdown(event) {
        // if called via {{on "focusout"}} check if new focus target is a submenu item
        if (event && event.relatedTarget && event.target.parentNode.contains(event.relatedTarget)) {
            return
        }
        this.currentlyOpenDropdown = null
    }

    /**
     * Toggles the mobile collapsed state of the navbar.
     * @memberOf OxiBase::Navbar
     */
    @action
    toggleCollapse() {
        this.isCollapsed = !this.isCollapsed;
    }

    /**
     * Collapses the mobile navbar (e.g. after a menu item is selected).
     * @memberOf OxiBase::Navbar
     */
    @action
    collapse() {
        this.isCollapsed = true;
    }
}

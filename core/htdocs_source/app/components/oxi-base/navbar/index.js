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
 * @param { array } items - array of menu item specifications:
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

    @action
    getRootItemClasses(index) {
        let classes = "py-1 ps-2 px-lg-3"
        if (index != 0) {
            classes += " border-start border-1 border-secondary-subtle"
        }
        return classes
    }

    @action
    openDropdown(index) {
        this.currentlyOpenDropdown = index
    }

    @action
    closeDropdown(event) {
        // if called via {{on "focusout"}} check if new focus target is a submenu item
        if (event && event.relatedTarget && event.target.parentNode.contains(event.relatedTarget)) {
            return
        }
        this.currentlyOpenDropdown = null
    }

    @action
    toggleCollapse() {
        this.isCollapsed = !this.isCollapsed;
    }

    @action
    collapse() {
        this.isCollapsed = true;
    }
}

import Component from '@glimmer/component'
import { action } from '@ember/object'

/**
 * Shows a formatted status message.
 *
 * ```html
 * <OxiBase::Status @def={{this.model.status}} />
 * ```
 *
 * @param { hash } def - Hash containing the element `message` and optionally `level` and `href`
 * @class OxiBase::Status
 */
export default class OxiStatusComponent extends Component {
    @action
    getStatusClass(level) {
        if (level === "error") { return "alert-danger" }
        if (level === "success") { return "alert-success" }
        if (level === "warn") { return "alert-warning" }
        return "alert-info"
    }
}

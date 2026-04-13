import Component from '@glimmer/component'
import { action } from '@ember/object'

/**
 * Shows a formatted status message.
 *
 * ```html
 * <OxiBase::Status @def={{this.model.status}} />
 * ```
 *
 * @param { object } def - Status definition.
 * @param { string } def.message - The status message text.
 * @param { string } [def.level] - Severity level: `'error'`, `'success'`, `'warn'`, or `'info'` (default).
 * @param { string } [def.href] - Link URL shown alongside the message.
 * @class OxiBase::Status
 */
export default class OxiStatusComponent extends Component {
    /**
     * Maps a severity level string to the corresponding Bootstrap alert CSS class.
     * Unknown levels default to `"alert-info"`.
     * @memberOf OxiBase::Status
     */
    @action
    getStatusClass(level) {
        if (level === "error") { return "alert-danger" }
        if (level === "success") { return "alert-success" }
        if (level === "warn") { return "alert-warning" }
        return "alert-info"
    }
}

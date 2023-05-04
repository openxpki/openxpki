import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { action, set as emSet } from "@ember/object"
import { debug } from '@ember/debug'
import { service } from '@ember/service'
import Clickable from 'openxpki/data/clickable'

/**
 * Low level clickable implementation supporting any visual representation.
 *
 * ```html
 * // FIXME
 * ```
 *
 * @class OxiBase::Clickable
 * @extends Component
 */
export default class OxiClickableComponent extends Component {
    @service router
    @service('oxi-content') content

    clickable = null
    @tracked showConfirmDialog = false

    get isLink() {
        return this.args.clickable.href ? true : false
    }

    constructor() {
        super(...arguments)
        this.clickable = Clickable.fromHash(this.args.clickable)
    }

    @action
    click(event) {
        debug("oxi-base/clickable: click")

        if (this.clickable.confirm) {
            emSet(this.clickable, "loading", true)
            this.showConfirmDialog = true
        } else {
            this.executeAction()
        }

        // cancel click event - only effective if we are called via <a onclick="...">
        event?.preventDefault()
    }

    @action
    executeAction() {
        this.resetConfirmState()
        let c = this.clickable

        // external link
        if (this.isLink) {
            this.content.openLink(c.href, c.target)
        }
        // OpenXPKI call (page or action)
        else {
            c.loading = true
            if (c.onClick) {
                debug(`oxi-base/c: executeAction - custom onClick() handler`)
                c.onClick(c)
                .finally(() => c.loading = false)
            }
            else if (c.action) {
                debug(`oxi-base/c: executeAction - call to backend action '${c.action}'`)
                let request = { action: c.action }
                if (c.action_params) request = { ...c.action_params, ...request }
                this.content.updateRequest(request)
                .finally(() => c.loading = false)
            }
            else if (c.page) {
                debug(`oxi-base/c: executeAction - transition to page '${c.page}`)
                this.content.openPage(c.page, c.target)
                .finally(() => c.loading = false)
            }
            else {
                throw new Error("oxi-base/clickable: executeAction - nothing to do. No 'action', 'page' or 'onClick' specified")
            }
        }
    }

    @action
    resetConfirmState() {
        emSet(this.clickable, "loading", false)
        this.showConfirmDialog = false
    }
}

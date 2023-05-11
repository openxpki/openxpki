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
 * <OxiBase::Clickable @clickable={{this.clickable}} as |clickHandler isLoading|>
 *     <BsButton
 *         ...attributes
 *         @onClick={{clickHandler}}
 *         disabled={{isLoading}}
 *     >
 *         {{yield}}
 *         {{#if isLoading}}
 *             <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
 *         {{/if}}
 *     </BsButton>
 * </OxiBase::Clickable>
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

        // custom client-side click handler (overrides server-sent config)
        if (c.onClick) {
            debug(`oxi-base/clickable: executeAction - custom onClick() handler`)
            c.loading = true
            c.onClick(c)
            .finally(() => c.loading = false)
        }
        else {
            // external link
            if (this.isLink) {
                debug(`oxi-base/clickable: executeAction - external link`)
                this.content.openLink(c.href, c.target)
            }
            // OpenXPKI call: action (POST)
            else if (c.action) {
                debug(`oxi-base/clickable: executeAction - call to backend action '${c.action}'`)
                c.loading = true
                let request = { action: c.action }
                if (c.action_params) request = { ...c.action_params, ...request }
                this.content.updateRequest(request)
                .finally(() => c.loading = false)
            }
            // OpenXPKI call: page (GET)
            else if (c.page) {
                debug(`oxi-base/clickable: executeAction - transition to page '${c.page}`)
                c.loading = true
                this.content.openPage(c.page, c.target)
                .finally(() => c.loading = false)
            }
            else {
                throw new Error("oxi-base/clickable: executeAction - nothing to do. No 'href', action', 'page' or 'onClick' specified")
            }
        }
    }

    @action
    resetConfirmState() {
        emSet(this.clickable, "loading", false)
        this.showConfirmDialog = false
    }
}

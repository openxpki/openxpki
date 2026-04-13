import Controller from '@ember/controller'
import { tracked } from '@glimmer/tracking'
import { action } from '@ember/object'
import { service } from '@ember/service'
import { A } from '@ember/array'
import { detect } from 'detect-browser'
import agents from 'virtual:browser-release-dates'
import copy from 'copy-text-to-clipboard'
import Link from 'openxpki/data/link'

/**
 * Controller for the main `/openxpki/:page` route.
 *
 * Handles query parameters (`startat`, `limit`, `force`, `trigger`),
 * browser-age detection, logout, page reload, and workflow-ID clipboard copy.
 *
 * @class OpenXpkiController
 * @extends Controller
 */
export default class OpenXpkiController extends Controller {
    @service('intl') intl
    @service('oxi-config') config
    @service('oxi-content') content
    @service router

    /*
      Reserved Ember property:
      defines the supported query parameters. Ember makes them available as this.count etc.
      https://api.emberjs.com/ember/release/classes/Controller
    */
    // binds the query parameter to the object property
    queryParams = [
        'startat',
        'limit',
        'force',
        'trigger', // must be declared for ember-source >= 6.11 even though we only read it from transition.to.queryParams in route.js
    ]
    @tracked startat = null
    @tracked limit = null
    @tracked force = null
    @tracked trigger = null

    @tracked loading = false

    // button to copy workflow ID to clipboard
    tempCopyElement = null

    /**
     * Returns a {@link Link} for the "copy workflow ID" button when the current
     * page has a `workflow_id`, or `null` otherwise.
     * @memberOf OpenXpkiController
     */
    get workflowCopyIdButton() {
        if (this.model?.top?.page?.workflow_id) {
            return Link.fromHash({
                label: this.intl.t('button.workflow.copy_id.label', { id: this.model.top.page.workflow_id }),
                tooltip: this.intl.t('button.workflow.copy_id.tooltip'),
                format: 'info',
                onClick: this.copyWorkflowIdToClipboard,
            })
        } else {
            return null
        }
    }

    /**
     * Returns the breadcrumb entries (filtered to items with a label) as an
     * Ember Array so `.lastObject` is available in templates.
     * @memberOf OpenXpkiController
     */
    get breadcrumbs() {
        let bc = (this.model.breadcrumbs || []).filter(el => el.label)
        return A(bc) // Ember Array allows to query .lastObject
    }

    /**
     * Returns a human-readable browser name+version string when the detected
     * browser is older than 2 years, or `null` if the browser is current or
     * unrecognised.
     * @memberOf OpenXpkiController
     */
    get oldBrowser() {
        const old_age = 2 * 365

        // map detect-browser names to caniuse names
        const map = {
            'edge' : 'edge',
            'edge-ios': 'ios_saf',
            'samsung': 'samsung',
            'edge-chromium': 'edge',
            'chrome': 'chrome',
            'firefox': 'firefox',
            'opera-mini': 'op_mini',
            'opera': 'opera',
            'ie': 'ie',
            'bb10': 'bb',
            'android': 'android',
            'ios': 'ios_saf',
            'safari': 'safari',
        }

        const browser = detect()
        if (!browser) return null

        // translate 'detect-browser' name to 'caniuse' name
        let name = map[browser.name] || browser.name
        if (name == 'chrome' && browser.os.match(/android/i)) name = 'and_chr'
        if (name == 'firefox' && browser.os.match(/android/i)) name = 'and_ff'

        // look if 'caniuse' knows this browser
        let agent = agents[name]
        if (!agent) return null

        // look if 'caniuse' knows this version
        let version = browser.version
        const known_version = Object.keys(agent.release_date).find(v => version.match(new RegExp(`^${v}(\\.|$)`)))
        if (!known_version) return null

        // calculate browser age (release date)
        let release_date = agent.release_date[known_version]
        if (!release_date) return null

        let now = parseInt(new Date() / 1000)
        let age = parseInt((now - release_date) / (60*60*24))

        if (age < old_age) return null

        console.info(`Detected browser "${agent.browser} ${known_version}" is ${age} days old (max. supported browser age: ${old_age} days)`)
        return `${agent.browser} ${known_version}`
    }

    /**
     * Clears the active tenant and navigates to the logout page.
     * @memberOf OpenXpkiController
     */
    @action
    logout(event) {
        if (event) { event.stopPropagation(); event.preventDefault() }
        this.content.setTenant(null);
        this.content.openPage({ name: 'logout', target: this.content.TARGET.TOP, force: true, params: { trigger: 'nav' } })
    }

    /**
     * Reloads the current page via `window.location.reload()`.
     * @memberOf OpenXpkiController
     */
    @action
    reload() {
        return window.location.reload();
    }

    /**
     * Stores a DOM element used as anchor for the clipboard textarea,
     * ensuring the copy stays within any active focus trap (e.g. a modal).
     * @memberOf OpenXpkiController
     */
    @action
    setTempCopyElement(element) {
        this.tempCopyElement = element
    }

    /**
     * Copies the current workflow ID to the clipboard.
     * @memberOf OpenXpkiController
     */
    @action
    async copyWorkflowIdToClipboard(/*event*/) {
        // target = DOM element where the temporary textarea will be appended,
        // to stay within a focus trap, like in a modal.
        // Conversion from number to string is required because copy() checks the type.
        copy(this.model.top.page.workflow_id+'', { target: this.tempCopyElement })

        /* eslint-disable-next-line no-console */
        console.info("Contents copied to clipboard")
    }
}

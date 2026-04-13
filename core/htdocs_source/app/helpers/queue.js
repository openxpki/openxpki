import Helper from "@ember/component/helper"

/**
 * Returns a function that call all given functions (or Promises).
 *
 * Example:
 * ```html
 * {{queue this.one this.two}}
 * ```
 * @module helper/queue
 */
export default class Queue extends Helper {
    /**
     * Returns a function that sequentially calls every action in `actions` when invoked.
     * @memberOf module:helper/queue
     */
    compute([...actions]) {
        return function() {
            for (const action of actions) {
                action()
            }
        }
    }
}

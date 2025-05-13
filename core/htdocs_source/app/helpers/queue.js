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
    compute([...actions]) {
        return function() {
            for (const action of actions) {
                action()
            }
        }
    }
}

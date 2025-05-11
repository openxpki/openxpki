import Helper from "@ember/component/helper"

/**
 * Call all given functions.
 *
 * Example:
 * ```html
 * {{queue this.one this.two}}
 * ```
 * @module helper/queue
 */
export default class Queue extends Helper {
    compute([...actions]) {
        return actions.reduce((chain, action) => {
            return chain.then((results) => {
                const result = action();
                return Promise.resolve(result).then(res => [...results, res])
            });
        }, Promise.resolve([]));
    }
}

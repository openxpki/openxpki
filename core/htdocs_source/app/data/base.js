import { debug } from '@ember/debug'

/**
 * Base class for data transfer objects ("DTOs": objects with minimal behaviour).
 *
 * The reasons to use DTOs instead of the plain hashes received from the
 * backend are:
 *
 * 1. to be able to use Ember `@tracked` properties so that certain properties
 * can be dynamically updated (e.g. `disabled` for buttons).
 *
 * 2. to prevent typos and make sure only attributes known to this client side
 * are transfered from the backend.
 *
 * @class Base
 */
export default class Base {
    static _type = 'app/data/base'
    static _idField = 'name'

    /**
     * Static method to create an instance with properties set to the given
     * hash values of the same name.
     * May also be given another instance of Base or a derived class.
     * @memberOf Base
     */
    static fromHash(sourceHash) {
        // don't convert if it's already an object of the target type
        if (sourceHash instanceof this) { return sourceHash }

        // new target instance
        let instance = new this() // "this" in static methods refers to class
        instance.setFromHash(sourceHash)
        return instance
    }

    /**
     * Set the instance properties to the given hash values of the same name.
     * May also be given another instance of Base or a derived class.
     * @memberOf Base
     */
    setFromHash(sourceHash) {
        if (typeof sourceHash === 'undefined' || sourceHash === null) return

        // list our and their properties
        let ourProps = this.getPropertyNames()
        let theirProps = sourceHash instanceof Base ? sourceHash.getPropertyNames() : Object.keys(sourceHash)
        let unknownProps = []

        for (const prop of theirProps) {
            if (ourProps.has(prop) === false) {
                unknownProps.push(prop)
                continue
            }
            let val = sourceHash[prop]

            /* HACK:
             * We use another instance to check the property types because
             * even a check via "typeof" on this.* would already trigger this
             * Ember error:
             * "You attempted to update `pagesizes` on `Pager`, but it had
             * already been used previously in the same computation.
             * Attempting to update a value after using it in a computation
             * can cause logical errors, infinite revalidation bugs, and
             * performance issues, and is not supported." */
            let dummy = new this.constructor()

            if (typeof dummy[prop] === 'string') {
                this[prop] = ''+val
            }
            else if (typeof dummy[prop] === 'number') {
                this[prop] = Number.parseFloat(val)
            }
            else if (typeof dummy[prop] === 'boolean') {
                this[prop] = !!val
            }
            else {
                this[prop] = val
            }
        }

        if (unknownProps.length > 0) {
            debug(
                `Attempt to set unknown properties in ${this.constructor.name} instance "${sourceHash[this.constructor._idField] ?? '<unknown>'}": ${unknownProps.join(', ')}. `
                +`If you need to process these backend properties, please add them to ${this.constructor._type}.js or one of its ancestors.`
            )
        }

        this.validate()
    }

    /**
     * Clones the object and returns a new instance with the same properties.
     * @memberOf Base
     */
    clone() {
        let obj = new this.constructor()
        for (const k of this.getPropertyNames(true).values()) { obj[k] = this[k] }
        return obj
    }

    /**
     * Returns all non-private properties (i.e. no leading underscore) as a plain hash/object
     * @memberOf Base
     */
    toPlainHash() {
        let hash = {}
        Array.from(this.getPropertyNames().values())
            .filter(k => k.charAt(0) != '_')
            .forEach(k => hash[k] = this[k])
        return hash
    }

    /**
     * Returns a Set of all (inherited) instance properties up to (but excl.)
     * this Base class. Also includes @tracked properties.
     * Pass in `true` as first argument to only return writable properties
     * (i.e. exclude getters).
     * @memberOf Base
     */
    getPropertyNames(writableOnly = false) {
        let obj = this
        const props = new Set()
        do {
            if (obj.constructor.name === 'Base') { break }
            Object.getOwnPropertyNames(obj)
                .filter(p => writableOnly ? Object.getOwnPropertyDescriptor(obj, p).writable : true)
                .forEach(p => props.add(p))
            obj = Object.getPrototypeOf(obj)
        } while (obj)
        return props
    }

    /**
     * To be overwritten by inheriting classes to check attributes.
     * @memberOf Base
     */
    validate() {}
}

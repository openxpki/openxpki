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

        // list our and their properties
        let ourProps = instance.getPropertyNames()
        let theirProps = sourceHash instanceof Base ? sourceHash.getPropertyNames() : Object.keys(sourceHash)

        for (const prop of theirProps) {
            if (ourProps.has(prop) === false) {
                /* eslint-disable-next-line no-console */
                console.error(`Attempt to set unknown property "${prop}" in ${this.name} instance "${sourceHash[this._idField] ?? '<unknown>'}". `)
                console.error(`If it's a new property, please add it to ${this._type}.js`)
            }
            else {
                instance[prop] = sourceHash[prop]
            }
        }
        return instance
    }

    /**
     * Clones the object and returns a new instance with the same properties.
     * @memberOf Base
     */
    clone() {
        let obj = new this.constructor()
        for (const k of this.getPropertyNames().values()) { obj[k] = this[k] }
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
     * @memberOf Base
     */
    getPropertyNames() {
        let obj = this
        const props = new Set()
        do {
            if (obj.constructor.name === 'Base') { break }
            Object.getOwnPropertyNames(obj).forEach(p => props.add(p))
            obj = Object.getPrototypeOf(obj)
        } while (obj)
        return props
    }
}

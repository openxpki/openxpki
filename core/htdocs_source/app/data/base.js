/*
 * Button data
 */
export default class Base {
    static get _type() { return 'app/data/base' }
    static get _idField() { return 'name' }

    /**
     * Static method to create an instance with the properties set to the given
     * hash values of the same name.
     */
    static fromHash(sourceHash) {
        // don't convert if it's already an object of the target type
        if (sourceHash instanceof this) { return sourceHash }

        // new target instance
        let instance = new this() // "this" in static methods refers to class

        let props = [
            ...Object.getOwnPropertyNames(instance),                        // "normal" instance properties
            ...Object.getOwnPropertyNames(Object.getPrototypeOf(instance)), // @tracked properties
        ]

        for (const prop of Object.keys(sourceHash)) {
            if (props.findIndex(el => el == prop) == -1) {
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
     */
    clone() {
        let obj = new this.constructor()
        // @tracked properties
        Object.keys(Object.getPrototypeOf(this)).forEach(k => obj[k] = this[k])
        // public class properties
        Object.keys(this).forEach(k => obj[k] = this[k])
        return obj
    }

    /**
     * Returns all non-private properties (i.e. no leading underscore) as a plain hash/object
     */
    toPlainHash() {
        let hash = {}
        // @tracked non-private properties
        Object.keys(Object.getPrototypeOf(this))
            .filter(k => k.charAt(0) != '_')
            .forEach(k => hash[k] = this[k])
        // non-private class properties
        Object.keys(this)
            .filter(k => k.charAt(0) != '_')
            .forEach(k => hash[k] = this[k])
        return hash
    }
}

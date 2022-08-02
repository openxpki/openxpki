/*
 * Button data
 */
export default class Base {
    static get _type() { return 'app/data/base' }
    static get _idField() { return 'name' }

    /**
     * Static method to create an instance with the attributes set to the given
     * hash values of the same name.
     */
    static fromHash(sourceHash) {
        let instance = new this() // "this" in static methods refers to class
        for (const attr of Object.keys(sourceHash)) {
            // @tracked properties are prototype properties, the others instance properties
            if (! (Object.prototype.hasOwnProperty.call(Object.getPrototypeOf(this), attr) || Object.prototype.hasOwnProperty.call(instance, attr))) {
                /* eslint-disable-next-line no-console */
                console.error(`Attempt to set unknown property "${attr}" in ${this.name} instance "${sourceHash[this._idField] ?? '<unknown>'}". `)
                console.error(`If it's a new property, please add it to ${this._type}.js`)
            }
            else {
                instance[attr] = sourceHash[attr]
            }
        }
        return instance
    }

    /**
     * Clones the object and returns a new instance with the same attributes.
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

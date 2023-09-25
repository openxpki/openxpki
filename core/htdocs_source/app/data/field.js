import { tracked } from '@glimmer/tracking'
import Base from './base';

/*
 * Form field data:
 * Underscore prefixed properties are meta data that is only used in
 * oxi-section/form and oxi-section/form/field components.
 * They will be excluded from the plain hash that is passed down to the field
 * implementations oxi-section/form/field/* via @content.
 */
export default class Field extends Base {
    static _type = 'app/data/field'
    static _idField = 'name'

    /*
     * Common
     */
    type
    name
    _refName // internal use: original name, needed for dynamic input fields where 'name' can change
    _id = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER) // internal use: random ID
    value
    label
    is_optional
    tooltip
    placeholder
    width
    actionOnChange
    @tracked _error         // client-side error state
    @tracked _server_error  // server-side error state
    autofill
    ecma_match
    /*
     * Clonable fields
     */
    clonable = false
    max
    // following attributes need to be tracked because they are updated after the field list
    @tracked _canDelete
    @tracked _canAdd
    @tracked _lastCloneInGroup
    _focusClone = false // initially focus clone after adding (done in setFocusInfo() below after callback by oxisection/form/field)
    /*
     * Dynamic input fields
     */
    keys
    /*
     * oxisection/form/field/datetime
     */
    //
    timezone
    /*
     * oxisection/form/field/select
     */
    options
    placeholder
    editable
    /*
     * oxisection/form/field/static
     */
    verbose
    /*
     * oxisection/form/field/text
     */
    autocomplete_query
    /*
     * oxisection/form/field/textarea
     */
    rows
    allow_upload


    /**
     * Clones the object and returns a new instance with the same properties
     * except for the `_id` which gets a new random value.
     * @memberOf Field
     */
    clone() {
        let cloneField = super.clone()
        cloneField._id = Math.floor(Math.random() * Number.MAX_SAFE_INTEGER)
        return cloneField
    }
}

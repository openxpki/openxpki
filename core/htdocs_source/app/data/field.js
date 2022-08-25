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
    static get _type() { return 'app/data/field' }
    static get _idField() { return 'name' }

    /*
     * Common
     */
    type
    name
    _refName // internal use: original name, needed for dynamic input fields where 'name' can change
    value
    label
    is_optional
    tooltip
    placeholder
    actionOnChange
    @tracked _error // client- or server-side error state
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
    prompt
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
}

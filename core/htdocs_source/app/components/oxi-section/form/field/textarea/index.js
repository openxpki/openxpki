import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import { debug } from '@ember/debug';

/**
 * Multi-line textarea field implementation, with optional file upload and drag-and-drop.
 * Binary file content is base64-encoded before being passed to `onChange`.
 *
 * @param { object } content - Plain field hash (from {@link Field}).
 * @param { string } [content.value] - Initial text content.
 * @param { string } [content.placeholder] - Placeholder text.
 * @param { number } [content.rows] - Number of visible rows. Default: `10`.
 * @param { boolean } [content.is_optional] - When falsy the textarea is marked required.
 * @param { boolean } [content.allow_upload] - Show a file-upload button and accept drag-and-drop.
 * @param { object } [content.autofill] - Autofill config forwarded to {@link OxiSection::Form::AutoFill}.
 * @param { function } onChange - Callback invoked with the new value (string or ArrayBuffer for binary files).
 * @param { function } setFocusInfo - Callback to register the textarea element for focus management.
 * @param { function } encodeFields - Callback to encode sibling field values (forwarded to autofill).
 * @param { string } [error] - Validation error message to display below the textarea.
 *
 * @class OxiSection::Form::Field::Textarea
 * @extends Component
 */
export default class OxiFieldTextareaComponent extends Component {
    @service('intl') intl;

    fileUploadElement = null;

    @tracked value;             // the actual value
    @tracked textOutput = "";   // what is shown in the text field
    @tracked filename = "-";
    @tracked lockTextInput = false;

    constructor() {
        super(...arguments);

        this.textOutput = this.args.content.value;
        if (this.textOutput) this.setValue(this.textOutput);
    }

    /**
     * Returns the number of visible textarea rows (default: `10`).
     * @memberOf OxiSection::Form::Field::Textarea
     */
    get rows() { return this.args.content?.rows || 10 }

    /**
     * Returns `true` when a non-empty value (text or binary) is set.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    get hasContent() { return this.value ? true : false }

    /**
     * Prevents Enter key from bubbling up to the parent form's submit handler inside a textarea.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    onKeydown(event) {
        // prevent form submit when hitting ENTER
        if (event.key === 'Enter') {
            event.stopPropagation();
        }
    }

    /**
     * Stores a reference to the hidden `<input type="file">` element so it can be triggered programmatically.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    setFileUploadElement(element) {
        this.fileUploadElement = element;
    }

    /**
     * Propagates a manual text-input change to `setValue`.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    onInput(evt) {
        this.setValue(evt.target.value);
    }

    /**
     * Programmatically clicks the hidden file input to open the system file picker.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    openFileUpload() {
        this.fileUploadElement.click();
    }

    /**
     * Handles file selection via the `<input type="file">` element.
     * Resets the input value after reading so the same file can be re-selected.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    async fileSelected(evt) {
        if (evt.target.type !== "file") { return }
        try {
            await this.setFile(evt.target.files[0])
        } finally {
            // Reset file input value as otherwise <input type="file"> will not fire
            // a "change" event on Chrome browsers if the same file is selected again
            // (after hitting our "Reset" button which does not affect the input).
            evt.target.value = null
        }
    }

    /**
     * Handles a file dropped onto the textarea via drag-and-drop.
     * No-op when `allow_upload` is not set.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    async fileDropped(evt) {
        evt.stopPropagation()
        evt.preventDefault()
        if (!this.args.allow_upload) return
        try {
            await this.setFile(evt.dataTransfer.files[0])
        } catch(e) {
            /* eslint-disable-next-line no-console */
            console.error('oxifield-textarea: error reading dropped file', e)
        }
    }

    /**
     * Sets the drag-over drop effect to `'copy'` so the OS cursor reflects the drop action.
     * No-op when `allow_upload` is not set.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    showCopyEffect(evt) {
        evt.stopPropagation();
        evt.preventDefault();
        if (!this.args.allow_upload) return;
        evt.dataTransfer.dropEffect = 'copy'; // show as "copy" action
    }

    /**
     * Clears the current value, text output, filename and unlocks the text input.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    resetInput() {
        this.setValue(null);
        this.textOutput = "";
        this.filename = "";
        this.lockTextInput = false;
    }

    // expects a File object
    setFile(file) {
        debug(`oxifield-textarea: setFile() - loading contents of ${file.name}`)

        return new Promise((resolve, reject) => {
            // convert file to ArrayBuffer
            let reader = new FileReader()
            reader.onload = (e) => {
                this.setFileData(e.target.result, file.name)
                resolve()
            }
            reader.onerror = (e) => reject(e.target.error)
            reader.readAsArrayBuffer(file)
        })
    }

    setFileData(arrayBuffer, sourceLabel) {
        this.lockTextInput = true;
        this.filename = sourceLabel;
        this.setValue(arrayBuffer);

        // show contents if it's a text block
        const textStart = "-----BEGIN";
        let start = String.fromCharCode(...new Uint8Array(arrayBuffer.slice(0, textStart.length)));
        let isText = (start === textStart);
        let isSmall = (arrayBuffer.byteLength < 10*1024);
        if (isText && isSmall) {
            this.textOutput = String.fromCharCode(...new Uint8Array(arrayBuffer));
        }
        else {
            this.textOutput = `<${!isSmall
                ? this.intl.t('component.oxifield_textarea.large_file')
                : this.intl.t('component.oxifield_textarea.binary_file')
            }>`;
        }
    }

    /**
     * Receives a string from the autofill component, converts it to an ArrayBuffer via a Blob,
     * and delegates to `setFileData` so the content is handled identically to a dropped file.
     * @memberOf OxiSection::Form::Field::Textarea
     */
    @action
    setAutofill(val, sourceLabel) {
        // convert string to ArrayBuffer
        let reader = new FileReader();
        reader.onload = (e) => this.setFileData(e.target.result, sourceLabel);

        debug(`oxifield-textarea: setAutofill() - setting autofill response from ${sourceLabel}`);
        reader.readAsArrayBuffer(new Blob([val], { type : 'text/plain' }));
    }

    setValue(value) {
        this.value = value;
        this.args.onChange(value);
    }
}

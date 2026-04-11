import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import { debug } from '@ember/debug';

/**
 * Multi-line textarea field implementation, with optional file upload and drag-and-drop.
 * Binary file content is base64-encoded before being passed to `onChange`.
 *
 * @param { object } content - Plain field hash (from {@link Field}):
 *   - `value` { string } - Initial text content.
 *   - `placeholder` { string } - Placeholder text.
 *   - `rows` { number } - Number of visible rows. Default: `10`.
 *   - `is_optional` { boolean } - When falsy the textarea is marked required.
 *   - `allow_upload` { boolean } - Show a file-upload button and accept drag-and-drop.
 *   - `autofill` { object } - Autofill config forwarded to `OxiSection::Form::AutoFill`.
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

    get rows() { return this.args.content?.rows || 10 }
    get hasContent() { return this.value ? true : false }

    @action
    onKeydown(event) {
        // prevent form submit when hitting ENTER
        if (event.key === 'Enter') {
            event.stopPropagation();
        }
    }

    @action
    setFileUploadElement(element) {
        this.fileUploadElement = element;
    }

    @action
    onInput(evt) {
        this.setValue(evt.target.value);
    }

    @action
    openFileUpload() {
        this.fileUploadElement.click();
    }

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

    @action
    showCopyEffect(evt) {
        evt.stopPropagation();
        evt.preventDefault();
        if (!this.args.allow_upload) return;
        evt.dataTransfer.dropEffect = 'copy'; // show as "copy" action
    }

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
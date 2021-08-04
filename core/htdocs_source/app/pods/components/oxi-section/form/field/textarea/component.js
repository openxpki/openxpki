import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { inject } from '@ember/service';
import { debug } from '@ember/debug';

export default class OxiFieldTextareaComponent extends Component {
    @inject('intl') intl;

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

    get cols() { return (this.args.content.textAreaSize || {}).width || 150 }
    get rows() { return (this.args.content.textAreaSize || {}).height || 10 }
    get hasContent() { return this.value ? true : false }

    @action
    onKeydown(event) {
        // prevent form submit when hitting ENTER
        if (event.keyCode === 13) {
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
    fileSelected(evt) {
        if (evt.target.type !== "file") { return }
        this.setFile(evt.target.files[0]);
    }

    @action
    fileDropped(evt) {
        evt.stopPropagation();
        evt.preventDefault();
        this.setFile(evt.dataTransfer.files[0]);
    }

    @action
    showCopyEffect(evt) {
        evt.stopPropagation();
        evt.preventDefault();
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
        // convert file to ArrayBuffer
        let reader = new FileReader();
        reader.onload = (e) => this.setFileData(e.target.result, file.name);

        debug(`oxifield-textarea: setFile() - loading contents of ${file.name}`);
        reader.readAsArrayBuffer(file);
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
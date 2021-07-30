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

        // Add autofill behaviour
        if (this.args.content.autofill) this.args.initAutofill(
            // pass in function that fills in the result
            val => {
                // convert string to ArrayBuffer
                let reader = new FileReader();
                reader.onload = (e) => this.setFileData(e.target.result, this.args.autofillResultLabel);
                reader.readAsArrayBuffer(new Blob([val], { type : 'text/plain' }));
            }
        );
    }

    get cols() { return (this.args.content.textAreaSize || {}).width || 150 }
    get rows() { return (this.args.content.textAreaSize || {}).height || 10 }
    get externalSources() { return this.args.content.autofill || this.args.content.allow_upload }

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

        debug(`oxifield-uploadarea: setFile() - loading contents of ${file.name}`);
        reader.readAsArrayBuffer(file);
    }

    setFileData(arrayBuffer, name) {
        this.lockTextInput = true;
        this.filename = name;
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
                ? this.intl.t('component.oxifield_uploadarea.large_file')
                : this.intl.t('component.oxifield_uploadarea.binary_file')
            }>`;
        }
    }

    setValue(value) {
        this.value = value;
        this.args.onChange(value);
    }
}
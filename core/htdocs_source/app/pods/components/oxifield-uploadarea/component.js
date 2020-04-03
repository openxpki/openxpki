import Component from '@glimmer/component';
import { action, computed } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { getOwner } from '@ember/application';
import { guidFor } from '@ember/object/internals';
import { debug } from '@ember/debug';

let TEXT_TYPES = [
    "application/pkcs8",
    "application/pkcs10",
    "application/x-x509-ca-cert",
    "application/x-x509-user-cert",
    "application/x-pkcs7-crl",
    "application/x-pem-file",
    "application/x-pkcs12",
];

export default class OxifieldUploadComponent extends Component {
    fileUploadElementId = 'oxi-fileupload-' + guidFor(this);

    @tracked data;
    @tracked textOutput = "";
    @tracked filename = "";
    @tracked lockTextInput = false;

    get cols() { return (this.args.content.textAreaSize || {}).width || 150 }
    get rows() { return (this.args.content.textAreaSize || {}).height || 10 }

    @action
    setTextInput(evt) {
        this.data = evt.target.value;
    }

    @action
    openFileUpload(evt) {
        document.getElementById(this.fileUploadElementId).click();
    }

    @action
    fileSelected(evt) {
        console.log(this.getElementById);
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
        this.data = null;
        this.textOutput = "";
        this.filename = "";
        this.lockTextInput = false;
    }

    // expects a File object
    setFile(file) {
        console.log("setFile", file);
        this.lockTextInput = true;
        this.filename = file.name;

        let reader = new FileReader();
        reader.onload = (e) => this.setFileData(e.target.result);

        debug(`oxifield-uploadarea: setFile() - loading contents of ${file.name}`);
        reader.readAsArrayBuffer(file);
    }

    setFileData(arrayBuffer) {
        this.data = arrayBuffer;

        // show contents if it's a text block
        const textStart = "-----BEGIN";
        let start = String.fromCharCode.apply(null, new Uint8Array(arrayBuffer.slice(0, textStart.length)));
        let isText = (start === textStart);
        let isSmall = (arrayBuffer.byteLength < 10*1024);
        if (isText && isSmall) {
            this.textOutput = String.fromCharCode.apply(null, new Uint8Array(arrayBuffer));
        }
        else {
            this.textOutput = !isSmall ? "<large file chosen>" : "<binary file>";
        }
    }
}
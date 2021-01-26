import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { debug } from '@ember/debug';

/*
 * NOTE: this component differs from others in that it does not
 * react to changes of its parameters (this.args.*).
 * Two reasons:
 * 1. it makes no sense to have presets for an upload area, or modified
 *    values from a parent component
 * 2. the logic for disabling buttons etc. would not work as we would
 *    not know if a value set somewhere else was a manual input or came
 *    from a file.
 */
export default class OxiFieldUploadComponent extends Component {
    @service('intl') intl;

    fileUploadElement = null;

    @tracked data;
    @tracked textOutput = "";
    @tracked filename = "";
    @tracked lockTextInput = false;

    get cols() { return (this.args.content.textAreaSize || {}).width || 150 }
    get rows() { return (this.args.content.textAreaSize || {}).height || 10 }

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
    setTextInput(evt) {
        this.setData(evt.target.value);
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
        this.setData(null);
        this.textOutput = "";
        this.filename = "";
        this.lockTextInput = false;
    }

    // expects a File object
    setFile(file) {
        this.lockTextInput = true;
        this.filename = file.name;

        let reader = new FileReader();
        reader.onload = (e) => this.setFileData(e.target.result);

        debug(`oxifield-uploadarea: setFile() - loading contents of ${file.name}`);
        reader.readAsArrayBuffer(file);
    }

    setFileData(arrayBuffer) {
        this.setData(arrayBuffer);

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

    setData(data) {
        this.data = data;
        this.args.onChange(data);
    }
}
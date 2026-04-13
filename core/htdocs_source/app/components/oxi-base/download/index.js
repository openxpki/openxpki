import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { debug } from '@ember/debug';
import copy from 'copy-text-to-clipboard';

/**
 * Offers a file for download, optionally showing a button
 * and optionally auto-starting the download.
 *
 * ```html
 * <OxiBase::Download @type="base64" @data={{this.fileData}} @mimeType="text/plain" @fileName="book.txt" @autoDownload={{true}} @hide={{true}}/>
 * <OxiBase::Download @type="link" @data="img/logo.png" @fileName="openxpki.png" />
 * ```
 *
 * @param { string } type - Data type: `"link"` for a plain URL, `"base64"` for Base64-encoded
 *   binary content, or omit/any other value for plain text content.
 * @param { string } data - The file content or URL. For `type="link"`: a URL string.
 *   For `type="base64"`: a Base64-encoded string. Otherwise: plain text.
 * @param { string } [mimeType] - MIME type for the generated blob. Not used for `type="link"`.
 *   Auto-detected from content when possible. Default: `'application/binary'` (base64) or
 *   `'text/plain'` (plain).
 * @param { string } [fileName] - Suggested download filename. Auto-detected from content when
 *   possible. Default: `'openxpki.dat'`. Not set by default for `type="link"`.
 * @param { boolean } [autoDownload] - Trigger the download automatically on render.
 * @param { boolean } [hide] - Hide the download button. Only effective when `@autoDownload` is
 *   also `true`.
 * @param { boolean } [showContent] - Show a read-only text preview of the content (only for
 *   non-link types and content smaller than 10 KB).
 * @class OxiBase::Download
 */
export default class OxiDownloadComponent extends Component {
    type = this.args.type || "";
    isLink = this.type == "link";
    isBase64 = this.type.match(/^base64$/i);
    isPlain = !this.isLink && !this.isBase64;

    @tracked url;
    @tracked fileName;
    @tracked rawData; // will NOT be set for @type="link"
    @tracked mimeType; // will NOT be set for @type="link"

    baseElement;

    /**
     * Returns `true` when `@autoDownload` and `@hide` are both set (button is hidden).
     * @memberOf OxiBase::Download
     */
    get hide() {
        return this.args.autoDownload && this.args.hide;
    }

    /**
     * Returns `true` when `@showContent` is set, the type is not a link, and the
     * raw data is smaller than 10 KB.
     * @memberOf OxiBase::Download
     */
    get showContent() {
        return this.args.showContent && !this.isLink && this.rawData.length < 10*1024;
    }

    /**
     * Returns the button/link label: the filename when known, otherwise the URL.
     * @memberOf OxiBase::Download
     */
    get label() {
        return this.fileName ? this.fileName : this.url;
    }

    constructor() {
        super(...arguments);

        if (this.isLink) {
            debug(`oxi-download: data type = "link"`);
            this.url = this.args.data;
        }
        else {
            if (this.isBase64) {
                debug(`oxi-download: data type = "base64"`);
                this.rawData = atob(this.args.data);
                this.mimeType = this.args.mimeType || 'application/binary';
            }
            else {
                debug(`oxi-download: data type = "plain"`);
                this.rawData = this.args.data;
                this.mimeType = this.args.mimeType || 'text/plain';
            }
        }

        // auto-suggest filename
        this.fileName = "";
        if (this.args.fileName) {
            this.fileName = this.args.fileName;
        }
        else {
            if (this.isLink) {
                // don't set default fileName for links
            }
            else {
                this.fileName = 'openxpki.dat'; // set default
                const contentTypes = [
                    {
                        name: 'PEM encoded certificate',
                        regexp: new RegExp(/^-----BEGIN ([\w\s]*)CERTIFICATE-----[^-]+-----END ([\w\s]*)CERTIFICATE-----$/, 'ms'),
                        fileName: 'certificate.crt',
                        mimeType: 'application/x-x509-ca-cert',
                    },
                    {
                        name: 'PEM encoded private key',
                        regexp: new RegExp(/^-----BEGIN ([\w\s]*)PRIVATE KEY-----[^-]+-----END ([\w\s]*)PRIVATE KEY-----$/, 'ms'),
                        fileName: 'private-key.pem',
                        mimeType: 'application/',
                    },
                    {
                        name: 'PEM encoded public key',
                        regexp: new RegExp(/^-----BEGIN ([\w\s]*)PUBLIC KEY-----[^-]+-----END ([\w\s]*)PUBLIC KEY-----$/, 'ms'),
                        fileName: 'public-key.pem',
                        mimeType: 'application/',
                    },
                    {
                        name: 'PEM encoded certificate revocation list',
                        regexp: new RegExp(/^-----BEGIN PKCS7-----[^-]+-----END PKCS7-----$/, 'ms'),
                        fileName: 'revocation-list.crl',
                        mimeType: 'application/x-pkcs7-crl',
                    },
                ];
                for (const type of contentTypes) {
                    if (this.rawData.match(type.regexp)) {
                        debug(`oxi-download: successful content detection: ${type.name}`);
                        this.fileName = type.fileName;
                        this.mimeType = type.mimeType;
                        break;
                    }
                }
            }
        }

        if (!this.isLink) {
            let blob = this.stringToBlob(this.rawData, this.mimeType);
            this.url = URL.createObjectURL(blob);
        }
    }

    /**
     * Triggers the file download by creating and clicking a temporary `<a>` element.
     * @memberOf OxiBase::Download
     */
    @action
    download() {
        // perform download: create and click <a> element
        var link = document.createElement('a');
        link.style.display = 'none';
        link.addEventListener('click', (evt) => {
            link.href = this.url;
            link.target = '_blank';
            link.download = this.fileName;
            evt.stopPropagation();
        }, false);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        // URL.revokeObjectURL();
    }

    /**
     * Copies `rawData` to the clipboard (no-op for link type). Uses `baseElement`
     * as anchor to stay within any active focus trap.
     * @memberOf OxiBase::Download
     */
    @action
    copyToClipboard(/*event*/) {
        if (this.isLink) return;
        copy(this.rawData, { target: this.baseElement }); // target = DOM element where the temporary textarea will be appended,
                                                          // to stay within a focus trap, like in a modal.
        /* eslint-disable-next-line no-console */
        console.info("Contents copied to clipboard");
    }

    /**
     * Stores the base DOM element and auto-triggers `download()` if `@autoDownload` is set.
     * @memberOf OxiBase::Download
     */
    @action
    onInit(element) {
        this.baseElement = element;
        if (this.args.autoDownload) this.download();
    }

    /**
     * Updates `fileName` from the filename input field's change event.
     * @memberOf OxiBase::Download
     */
    @action
    onFileNameChange(event) {
        this.fileName = event.target.value;
    }

    /**
     * Converts a binary string to a `Blob` with the given MIME type.
     * @memberOf OxiBase::Download
     */
    stringToBlob(source, mimeType) {
        const byteArray = Uint8Array.from(
            source
            .split('')
            .map(char => char.charCodeAt(0))
        );
        return new Blob([byteArray], { type: mimeType });
    }
}

import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { debug } from '@ember/debug';
import copy from 'copy-text-to-clipboard';

/**
Offers a file for download, optionally showing a button
and optionally auto-starting the download.

```html
<OxiBase::Download @type="base64" @data={{this.fileData}} @mimeType="text/plain" @fileName="book.txt" @autoDownload={{true}} @hide={{true}}/>
<OxiBase::Download @type="link" @data="img/logo.png" @fileName="openxpki.png" />
```
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

    get hide() {
        return this.args.autoDownload && this.args.hide;
    }

    get showContent() {
        return this.args.showContent && !this.isLink && this.rawData.length < 10*1024;
    }

    get label() {
        return this.isLink ? this.url : this.fileName;
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

    @action
    copyToClipboard(/*event*/) {
        if (this.isLink) return;
        copy(this.rawData, { target: this.baseElement });
        /* eslint-disable-next-line no-console */
        console.info("Contents copied to clipboard");
    }

    @action
    onInsert(element) {
        this.baseElement = element;
        if (this.args.autoDownload) this.download();
    }

    @action
    onFileNameChange(event) {
        this.fileName = event.target.value;
    }

    stringToBlob(source, mimeType) {
        const byteArray = Uint8Array.from(
            source
            .split('')
            .map(char => char.charCodeAt(0))
        );
        return new Blob([byteArray], { type: mimeType });
    }
}

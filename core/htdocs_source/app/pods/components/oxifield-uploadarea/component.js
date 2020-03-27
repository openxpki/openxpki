import Component from '@ember/component';
import $ from "jquery";

let TEXT_TYPES = [
    "application/pkcs8",
    "application/pkcs10",
    "application/x-x509-ca-cert",
    "application/x-x509-user-cert",
    "application/x-pkcs7-crl",
    "application/x-pem-file",
    "application/x-pkcs12",
];

const OxifieldUploadComponent = Component.extend({
    cols: Em.computed("content.textAreaSize.width", function() {
        return this.get("content.textAreaSize.width") || 150;
    }),
    rows: Em.computed("content.textAreaSize.height", function() {
        return this.get("content.textAreaSize.height") || 10;
    }),
    canReadFile: Em.computed(function() {
        !!window.FileReader;
        return false;
    }),
    change: function(evt) {
        if (evt.target.type !== "file") {
            return;
        }
        if (this.get("canReadFile")) {
            let reader = new FileReader();
            reader.onload = (e) => {
                return $().find("textarea").val(reader.result);
            };
            let type = evt.target.files[0].type;
            if (/text\//.test(type) || TEXT_TYPES.indexOf(type) >= 0) {
                return reader.readAsText(evt.target.files[0]);
            } else {
                return reader.readAsDataURL(evt.target.files[0]);
            }
        } else {
            window.legacyUploadDone = () => {
                let body = frames['upload_target'].document.body;
                let resultStr = body.textContent || body.innerText;
                return this.set("content.value", JSON.parse(resultStr).result);
            };
            let file = $().find("input[type=file]");
            let fence = $("<div></div>");
            fence.insertAfter(file);
            let url = this.container.lookup("controller:config").get("url");
            let rtoken = this.container.lookup("route:openxpki").get("source.rtoken");
            let form = $(`<form method='post'
                enctype='multipart/form-data'
                action='${url}'
                target='upload_target'>
                    <input type="hidden" name="action" value="plain!upload">
                    <input type="hidden" name="_rtoken" value="${rtoken}">
                </form>`);
            form.append(file);
            form.appendTo("body");
            form.submit();
            file.insertAfter(fence);
            fence.remove();
            return form.remove();
        }
    }
});

export default OxifieldUploadComponent;
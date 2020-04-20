import Component from '@glimmer/component';
import { action } from '@ember/object';
import { getOwner } from '@ember/application';

export default class OxivalueFormatComponent extends Component {

/*

TODO: @action defuseValue(val) ...
--> an allen Stellen verwenden , wo im Template {{{value}}} steht

*/

    get format() {
        return (this.args.content.format || "text");
    }

    get valueStr() {
        return (new String(this.args.content.value || "")).replace(/\r/gm, "");
    }

    get valueSplitByNewline() {
        return this.valueStr.split(/\n/);
    }

    get timestamp() {
        return (this.args.content.value > 0
            ? moment.unix(this.args.content.value).utc().format("YYYY-MM-DD HH:mm:ss UTC")
            : "---");
    }

    get datetime() {
        return moment().utc(this.args.content.value).format("YYYY-MM-DD HH:mm:ss UTC");
    }

    get styledValue() {
        let m = this.args.content.value.match(/(([a-z]+):)?(.*)/gm);
        return {
            style: m[1],
            label: m[2],
        };
    }

    get defusedRawValue() {
        return this.defuseHtml(this.valueStr);
    }

    defuseHtml(html) {
        let parser = new DOMParser();
        let body = parser.parseFromString(html, "text/html").body;

        for (let script of body.querySelectorAll("script")) {
            script.remove();
        }
        for (let element of body.querySelectorAll("*")) {
            let attrs = element.attributes; // a NamedNodeMap, not an Array
            for (let i = attrs.length - 1; i >= 0; i--) {
                if (attrs[i].name.match(/^on/) || attrs[i].value.match(/javascript/)) {
                    element.removeAttribute(attrs[i].name);
                }
            }
        }

        return body.innerHTML;
    }

    @action
    click(evt) {
        let target = evt.target;
        if (target.tagName === "A" && target.target !== "_blank") {
            evt.stopPropagation();
            evt.preventDefault();
            getOwner(this).lookup("route:openxpki").sendAjax({
                page: target.href.split("#")[1].replace(/\/openxpki\//, ""),
                target: target.target,
            });
        }
    }
}

import Helper from "@ember/component/helper";

/*

Interpret the given string as HTML code and remove
<script> tags and "onXxx" / "javascript" attributes.

Useful for strings that will be output without escaping
using the triple mustache syntax (see example below).

Example:

    <span>{{{defuse this.label}}}</span>

*/
export default class Defuse extends Helper {
    compute([html]) {
        if (html === null || typeof html !== 'string') return "";

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
}

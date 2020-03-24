import $ from "jquery";
import Component from '@ember/component';
import types from "./types";

// see e524296ba39db2606d3cdb7f5bb83985ea51ec1d
jQuery.extend(jQuery.expr[':'], {
    cleanup: function(el) {
        let names = el.attributes
            .filter(attr => (/^on/.test(attr.nodeName) || /javascript/.test(attr.value)))
            .map(attr => attr.nodeName);
        for (const name of names) { el.removeAttribute(name) }
        return true;
    }
});

const OxivalueFormatComponent = Component.extend({
    onAnchorClick: Em.on("click", function(evt) {
        let target = evt.target;
        if (target.tagName === "A" && target.target !== "_blank") {
            evt.stopPropagation();
            evt.preventDefault();
            return this.container.lookup("route:openxpki").sendAjax({
                page: target.href.split("#")[1].replace(/\/openxpki\//, ""),
                target: target.target,
            });
        }
    }),
    types: types,
    formatedValue: Em.computed("content.format", "content.value", function() {
        let e = this.get("types")[this.get("content.format") || "text"](this.get("content.value"));
        let $el = $('<div/>');
        $el.html(e).find(':cleanup');
        $el.find('script').remove();
        return $el.html();
    })
});

export default OxivalueFormatComponent;
`import $ from "vendor/jquery"`
`import Em from "vendor/ember"`
`import types from "./types"`

jQuery.extend jQuery.expr[':'],
    cleanup: (el) ->
        ret = false
        names = (attr.nodeName for attr in el.attributes \
                    when /^on/.test(attr.nodeName) \
                    or /javascript/.test attr.value)
        for name in names
            el.removeAttribute name
        true

Component = Em.Component.extend
    onAnchorClick: Em.on "click", (evt) ->
        target = evt.target

        if target.tagName is "A" and target.target isnt "_blank"
            evt.stopPropagation()
            evt.preventDefault()
            @container.lookup("route:openxpki").sendAjax
                data:
                    page:target.href.split("#")[1].replace /\/openxpki\//, ""
                    target:target.target

    types: types

    formatedValue: Em.computed "content.format", "content.value", ->
        e = @get("types")[@get("content.format")||"text"](@get "content.value")
        $el = $ '<div/>'
        $el
            .html e
            .find ':cleanup'
        $el.find('script').remove()
        return $el.html()

`export default Component`

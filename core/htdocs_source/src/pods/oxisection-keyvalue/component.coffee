`import Em from "vendor/ember"`

Component = Em.Component.extend
    click: (evt) ->
        if evt.target.tagName is "A" and not /^(html|\/)/.test evt.target.href
            evt.stopPropagation()
            evt.preventDefault()
            @container.lookup("route:openxpki").sendAjax
                data:
                    page:evt.target.href.split("#")[1]
                    target:evt.target.target

    actions:
        execute: (btn) ->
            if btn.action
                @container.lookup("route:openxpki").sendAjax
                    data:
                        action:btn.action

`export default Component`

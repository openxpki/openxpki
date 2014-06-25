`import Em from "vendor/ember"`

Component = Em.Component.extend
    click: (evt) ->
        if evt.target.tagName is "A" and evt.target.target != '_blank'
            evt.stopPropagation()
            evt.preventDefault()
            @container.lookup("route:openxpki").sendAjax
                data:
                    page:evt.target.href.split("#")[1]
                    target:evt.target.target
        else if evt.target.tagName is "BUTTON"
            $(evt.target).addClass "btn-loading"

    actions:
        execute: (btn) ->
            if btn.action
                @container.lookup("route:openxpki").sendAjax
                    data:
                        action:btn.action
            else
                console.log('Transition');
                @container.lookup("route:openxpki").transitionTo "openxpki", btn.page

`export default Component`

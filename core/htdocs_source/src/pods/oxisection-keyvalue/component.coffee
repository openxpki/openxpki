`import Em from "vendor/ember"`

Component = Em.Component.extend
    isCertstatus: Em.computed.equal "content.format", "certstatus"
    isLink: Em.computed.equal "content.format", "link"
    isTimestamp: Em.computed.equal "content.format", "timestamp"

    actions:
        execute: (btn) ->
            if btn.action
                @container.lookup("route:openxpki").sendAjax
                    data:
                        action:btn.action

`export default Component`

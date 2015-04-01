`import Em from "vendor/ember"`

Component = Em.Component.extend
    classNameBindings: ["type"]

    type: Em.computed "content.type", -> "oxisection-" + @get "content.type"

    actions:
        buttonClick: (button) ->
            Em.set button, "loading", true
            if button.action
                @container.lookup("route:openxpki").sendAjax
                    data:
                        action:button.action
                .then ->
                    Em.set button, "loading", false
                , ->
                    Em.set button, "loading", false
            else
                @container.lookup("route:openxpki").transitionTo "openxpki",
                    button.page

`export default Component`

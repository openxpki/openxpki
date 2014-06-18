`import Em from "vendor/ember"`

Component = Em.Component.extend
    isForm: Em.computed.equal "content.type", "form"
    isGrid: Em.computed.equal "content.type", "grid"
    isKeyValue: Em.computed.equal "content.type", "keyvalue"
    isText: Em.computed.equal "content.type", "text"

`export default Component`

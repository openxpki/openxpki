`import Em from "vendor/ember"`

Router = Em.Router.extend()

Router.map -> @resource "openxpki", { path:"openxpki/:model_id"}

`export default Router`

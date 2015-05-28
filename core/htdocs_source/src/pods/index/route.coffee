`import Em from "vendor/ember"`

Route = Em.Route.extend
    redirect: (req) -> @transitionTo "openxpki", "welcome"

`export default Route`

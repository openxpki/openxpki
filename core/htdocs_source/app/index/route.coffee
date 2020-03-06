import Em from "components-ember"

Route = Em.Route.extend
    redirect: (req) -> @transitionTo "openxpki", "welcome"

export default Route

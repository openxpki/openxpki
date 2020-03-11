import Route from '@ember/routing/route'

export default Route.extend
    redirect: (req) -> @transitionTo "openxpki", "welcome"

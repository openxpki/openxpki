import Route from '@ember/routing/route'

export default Route.extend
    redirect: (model, transition) -> @transitionTo "openxpki", "welcome"

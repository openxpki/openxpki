import Em from "components-ember"

Controller = Em.ArrayController.extend
    needs: ["openxpki"]
    user: Em.computed.alias "controllers.openxpki.model.user"

export default Controller

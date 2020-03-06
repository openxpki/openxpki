import Em from 'components-ember'

import Bootstrap from 'bootstrap'
import BootstrapDatetimepicker from 'eonasdan-bootstrap-datetimepicker'
import BootstrapContextmenu from 'bootstrap-contextmenu'
import BootstrapTypeahead from 'bootstrap-3-typeahead'

import ApplicationFooterTemplate from "./components/applicationFooter/template"
import ApplicationHeaderTemplate from "./components/applicationHeader/template"
import ApplicationHeaderUserinfoTemplate from "./components/applicationHeaderUserinfo/template"
import OxiButtonContainerComponent from "./components/oxi-button-container/component"
import OxiButtonContainerTemplate from "./components/oxi-button-container/template"
import OxiButtonComponent from "./components/oxi-button/component"
import OxiButtonTemplate from "./components/oxi-button/template"
import OxifieldBoolTemplate from "./components/oxifield-bool/template"
import OxifieldCertIdentifierComponent from "./components/oxifield-certIdentifier/component"
import OxifieldCertIdentifierTemplate from "./components/oxifield-certIdentifier/template"
import OxifieldDatetimeComponent from "./components/oxifield-datetime/component"
import OxifieldDatetimeTemplate from "./components/oxifield-datetime/template"
import OxifieldMainComponent from "./components/oxifield-main/component"
import OxifieldMainTemplate from "./components/oxifield-main/template"
import OxifieldPasswordTemplate from "./components/oxifield-password/template"
import OxifieldPasswordverifyComponent from "./components/oxifield-passwordverify/component"
import OxifieldPasswordverifyTemplate from "./components/oxifield-passwordverify/template"
import OxifieldSelectComponent from "./components/oxifield-select/component"
import OxifieldSelectTemplate from "./components/oxifield-select/template"
import OxifieldStaticTemplate from "./components/oxifield-static/template"
import OxifieldTextTemplate from "./components/oxifield-text/template"
import OxifieldTextareaComponent from "./components/oxifield-textarea/component"
import OxifieldTextareaTemplate from "./components/oxifield-textarea/template"
import OxifieldUploadareaComponent from "./components/oxifield-uploadarea/component"
import OxifieldUploadareaTemplate from "./components/oxifield-uploadarea/template"
import OxisectionFormComponent from "./components/oxisection-form/component"
import OxisectionFormTemplate from "./components/oxisection-form/template"
import OxisectionGridComponent from "./components/oxisection-grid/component"
import OxisectionGridTemplate from "./components/oxisection-grid/template"
import OxisectionKeyvalueComponent from "./components/oxisection-keyvalue/component"
import OxisectionKeyvalueTemplate from "./components/oxisection-keyvalue/template"
import OxisectionMainComponent from "./components/oxisection-main/component"
import OxisectionMainTemplate from "./components/oxisection-main/template"
import OxisectionTextComponent from "./components/oxisection-text/component"
import OxisectionTextTemplate from "./components/oxisection-text/template"
import OxivalueFormatComponent from "./components/oxivalue-format/component"
import OxivalueFormatTemplate from "./components/oxivalue-format/template"
import OxivalueFormatTypes from "./components/oxivalue-format/types"
import PartialPaginationTemplate from "./components/partial-pagination/template"

App = Em.Application.extend
    # This is what the auto-generated ember-app.js used to contain:
    Resolver: Em.DefaultResolver.extend(
        ApplicationFooterTemplate: ApplicationFooterTemplate
        ApplicationHeaderTemplate: ApplicationHeaderTemplate
        ApplicationHeaderUserinfoTemplate: ApplicationHeaderUserinfoTemplate
        OxiButtonContainerComponent: OxiButtonContainerComponent
        OxiButtonContainerTemplate: OxiButtonContainerTemplate
        OxiButtonComponent: OxiButtonComponent
        OxiButtonTemplate: OxiButtonTemplate
        OxifieldBoolTemplate: OxifieldBoolTemplate
        OxifieldCertIdentifierComponent: OxifieldCertIdentifierComponent
        OxifieldCertIdentifierTemplate: OxifieldCertIdentifierTemplate
        OxifieldDatetimeComponent: OxifieldDatetimeComponent
        OxifieldDatetimeTemplate: OxifieldDatetimeTemplate
        OxifieldMainComponent: OxifieldMainComponent
        OxifieldMainTemplate: OxifieldMainTemplate
        OxifieldPasswordTemplate: OxifieldPasswordTemplate
        OxifieldPasswordverifyComponent: OxifieldPasswordverifyComponent
        OxifieldPasswordverifyTemplate: OxifieldPasswordverifyTemplate
        OxifieldSelectComponent: OxifieldSelectComponent
        OxifieldSelectTemplate: OxifieldSelectTemplate
        OxifieldStaticTemplate: OxifieldStaticTemplate
        OxifieldTextTemplate: OxifieldTextTemplate
        OxifieldTextareaComponent: OxifieldTextareaComponent
        OxifieldTextareaTemplate: OxifieldTextareaTemplate
        OxifieldUploadareaComponent: OxifieldUploadareaComponent
        OxifieldUploadareaTemplate: OxifieldUploadareaTemplate
        OxisectionFormComponent: OxisectionFormComponent
        OxisectionFormTemplate: OxisectionFormTemplate
        OxisectionGridComponent: OxisectionGridComponent
        OxisectionGridTemplate: OxisectionGridTemplate
        OxisectionKeyvalueComponent: OxisectionKeyvalueComponent
        OxisectionKeyvalueTemplate: OxisectionKeyvalueTemplate
        OxisectionMainComponent: OxisectionMainComponent
        OxisectionMainTemplate: OxisectionMainTemplate
        OxisectionTextComponent: OxisectionTextComponent
        OxisectionTextTemplate: OxisectionTextTemplate
        OxivalueFormatComponent: OxivalueFormatComponent
        OxivalueFormatTemplate: OxivalueFormatTemplate
        OxivalueFormatTypes: OxivalueFormatTypes
        PartialPaginationTemplate: PartialPaginationTemplate
    )

export default App

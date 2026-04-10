import section_chart          from './section-chart'
import section_form_text      from './section-form-text'
import section_form_select    from './section-form-select'
import section_form_dependants from './section-form-dependants'
import section_form_password  from './section-form-password'
import section_form_datetime  from './section-form-datetime'
import section_form_cloneable from './section-form-cloneable'
import section_form_various   from './section-form-various'
import section_form_tooltips  from './section-form-tooltips'
import section_buttons        from './section-buttons'
import section_grid           from './section-grid'
import section_keyvalue       from './section-keyvalue'
import section_tiles          from './section-tiles'
import section_cards          from './section-cards'
import section_cards_vertical from './section-cards-vertical'

const SESSION_ID = 'mock-session-test-1'
const RTOKEN     = 'mock-rtoken-test-1'

// Helper: derive nav label from the first section's content label.
const label = (main) => main[0].content.label

// nav() builds a clickable nav entry from a page key and its main content.
const nav = (key, main) => ({ label: label(main), key, page: key, main })

const FORM_SECTIONS = [
    nav('openxpki.test.form-text',       section_form_text),
    nav('openxpki.test.form-select',     section_form_select),
    nav('openxpki.test.form-dependants', section_form_dependants),
    nav('openxpki.test.form-password',   section_form_password),
    nav('openxpki.test.form-datetime',   section_form_datetime),
    nav('openxpki.test.form-cloneable',  section_form_cloneable),
    nav('openxpki.test.form-various',    section_form_various),
    nav('openxpki.test.form-tooltips',   section_form_tooltips),
]

const SECTIONS = [
    nav('openxpki.test.charts',         section_chart),
    nav('openxpki.test.keyvalue',       section_keyvalue),
    nav('openxpki.test.cards',          section_cards),
    nav('openxpki.test.cards-vertical', section_cards_vertical),
    nav('openxpki.test.buttons', section_buttons),
    nav('openxpki.test.grid',           section_grid),
    nav('openxpki.test.tiles',          section_tiles),
]

// Bootstrap response: sets up session, CSRF token, locale, and the test menu.
// This is what oxi-content.js:#bootstrap() expects from page=bootstrap!structure.
// Must include: rtoken, structure, session_id, language.
// Must NOT include a meaningful `main` - that is fetched separately.
export const bootstrapResponse = {
    session_id: SESSION_ID,
    rtoken:     RTOKEN,
    language:   'en',
    structure: [
        ...SECTIONS,
        { label: 'Forms', entries: FORM_SECTIONS.map(({ label, key, page }) => ({ label, key, page })) },
    ],
    user:      { name: 'test', role: 'admin', realname: 'Test User', role_label: 'Admin' },
    pki_realm: 'test',
    page:      {},
    status:    {},
}

const PAGE_BUTTONS = [
    { label: 'de-DE', format: 'optional', action: 'test!lang!de-DE' },
    { label: 'en-US', format: 'optional', action: 'test!lang!en-US' },
    { label: 'Local request', format: 'optional', href: 'http://localhost:7780/test-server', target: '_blank' },
]

// Keyed lookup used by the Pretender handler.
// session_id must be the same stable value so that #isBootstrapNeeded() returns false
// after the initial bootstrap (a changing session_id would re-trigger bootstrap on
// every page navigation, causing an infinite loop).
export const pages = Object.fromEntries(
    [...SECTIONS, ...FORM_SECTIONS].map(s => [s.key, { session_id: SESSION_ID, page: { buttons: PAGE_BUTTONS }, main: s.main, status: {} }])
)

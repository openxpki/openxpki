import { macroCondition, isDevelopingApp } from '@embroider/macros'
import ENV from 'openxpki/config/environment'
import { pages, bootstrapResponse } from './mock-responses'

let server = null
let currentLanguage = bootstrapResponse.language
let session_index = 0

export async function setupPretender() {
    if (!macroCondition(isDevelopingApp())) return
    if (server) return  // idempotent

    const { default: Pretender } = await import('pretender')
    server = new Pretender()

    server.get(`${ENV.rootURL}localconfig.yaml`, () => [
        200,
        { 'Content-Type': 'application/yaml' },
        'header:\n  logo: img/logo.png\n  title: Test page\n',
    ])

    server.get(`${ENV.rootURL}cgi-bin/webui.fcgi`, req => {
        const page = req.queryParams?.page
        console.info(`MOCK> GET page=${page}`)

        if (page === 'tooltip!user!123') {
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify({
                type: 'text', content: { description: 'Fred&nbsp;<b>Flintstone</b>' },
            })]
        }
        if (page === 'tooltip!chart') {
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify({
                type: 'chart',
                className: 'test-chart',
                content: {
                    options: { type: 'pie', title: 'Pie', width: 300, height: 150,
                               series: [{ label: 'Requested' }, { label: 'Renewed' }, { label: 'Revoked' }] },
                    data: [['2019', '14', '44', '30']],
                },
            })]
        }

        // Bootstrap call (always the first GET after app load)
        if (page === 'bootstrap!structure') {
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify({ ...bootstrapResponse, language: currentLanguage })]
        }

        // Initial page load: openxpki/route.js receives params.page = "test"
        // and calls requestPage({ page: "test" }). Return the landing page.
        if (page === 'test' || !page) {
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify(pages['openxpki.test.charts'])]
        }

        // Named test section pages
        if (pages[page]) {
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify(pages[page])]
        }

        console.warn(`MOCK> unhandled GET page=${page}`)
        return [200, { 'Content-Type': 'application/json' }, JSON.stringify({})]
    })

    server.get('/autofill', req => {
        return [200, { 'Content-Type': 'application/json' }, JSON.stringify(req.queryParams)]
    })

    server.post(`${ENV.rootURL}cgi-bin/webui.fcgi`, req => {
        console.info(`MOCK> POST`)
        const params = JSON.parse(req.requestBody)
        console.info('MOCK> params:', params)

        if (params?.action?.startsWith('test!lang!')) {
            currentLanguage = params.action.split('!')[2]
            // Return a changed session_id so #isBootstrapNeeded() triggers an
            // immediate re-bootstrap, which picks up the new language.
            session_index = session_index ? 0 : 1;
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify({ session_id: `lang-switch-${session_index}` })]
        }

        if (params?.action === 'text!autocomplete') {
            const val = params.text_autocomplete
            const comment = params.the_comment || '(not provided)'

            if (params._encrypted_jwt_secure_param !== 'fake_jwt_token')
                throw new Error('Encrypted JWT token was not sent')

            if (val === 'boom') return [200, { 'Content-Type': 'application/json' }, JSON.stringify({ error: 'There is no spoon.' })]
            if (val === 'void') return [200, { 'Content-Type': 'application/json' }, JSON.stringify([])]
            return [200, { 'Content-Type': 'application/json' }, JSON.stringify([
                { label: `Bag - ${comment}`, value: `${val}-123` },
                { label: `Box - ${comment}`, value: `${val}-567` },
                { label: `Bucket - ${comment}`, value: `${val}-890` },
            ])]
        }

        return [200, { 'Content-Type': 'application/json' }, JSON.stringify({})]
    })

    const localRequestPath = 'test-server'
    server.unhandledRequest = (verb, path, req) => {
        if (path.includes(localRequestPath)) return req.passthrough()
        console.info('MOCK> Unhandled request', verb, path)
    }
    server.handledRequest = function() {}
}

export function shutdownPretender() {
    server?.shutdown()
    server = null
}

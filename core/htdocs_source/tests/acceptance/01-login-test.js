import { module, test } from 'qunit'
import { visit, currentURL, currentRouteName, find, select, getRootElement, click, fillIn } from '@ember/test-helpers'
import { setupApplicationTest } from 'openxpki/tests/helpers'

function getButton(label) {
    // return getRootElement().ownerDocument.evaluate(`.//button[contains(., "${label}")]`, getRootElement()).iterateNext()
    return getRootElement().ownerDocument.evaluate(`.//button[text()="${label}"]`, getRootElement()).iterateNext()
}
function getElementWith(element, text) {
    return getRootElement().ownerDocument.evaluate(`.//${element}[text()="${text}"]`, getRootElement()).iterateNext()
}
function debugPageContents() {
    console.debug(getRootElement().ownerDocument.evaluate(`.//div[contains(@class,"tab-pane")]`, getRootElement()).iterateNext().innerHTML)
}
function pageContains(regexp) {
  return document.querySelector('div.tab-content').innerHTML.match(regexp)
}

module('Acceptance | 01 login', function (hooks) {
  setupApplicationTest(hooks)

  test('visiting /', async function (assert) {
    await visit('/')

    // Already at handler selection? We reset the Login process in this case...
    if (getElementWith('div', 'Username')) {
      console.warn('Username label present - resetting Login')
      let resetLink = getElementWith('a', 'Reset Login')
      if (resetLink) {
        console.warn('Click "Reset Login"')
        await click(resetLink)
      }
    }

    // Logged in? - Logout then
    if (getElementWith('a', 'Log out')) {
      console.warn('Logged in - logging out')
      await click(getElementWith('a', 'Log out'))
    }

    // Move away from "Logged out" page
    if (currentURL().match(/^\/openxpki\/login!logout/)) {
      console.warn('At "logged out" page - opening Login page')
      await visit('/')
    }

    assert.strictEqual(currentURL(), '/openxpki/login', 'correct redirection to /openxpki/login')

    assert.ok(Array.from(find('select').options).find(o => o.value == "Testing"), 'handler "Testing" available')
    await select(find('select'), 'Testing')

    assert.ok(getButton('Login'), '"Login" button present')
    await click(getButton('Login'))

    assert.ok(getElementWith('div', 'Username'), '"Username" label present')
    assert.ok(getButton('Login'), 'login button present')

    await fillIn(document.querySelector('input.form-control[type="text"]'), 'non')
    await fillIn(document.querySelector('input.form-control[type="password"]'), 'sense')
    await click(getButton('Login'))

    assert.ok(pageContains(new RegExp(/Login.*failed/, 'i')), 'login fails with wrong credentials')

    await fillIn(document.querySelector('input.form-control[type="text"]'), 'raop')
    await fillIn(document.querySelector('input.form-control[type="password"]'), 'openxpki')
    await click(getButton('Login'))

    assert.ok(pageContains(new RegExp(/Tokens of type certsign/, 'i')), 'login')

    await click(getElementWith('a', 'Log out'))

    assert.ok(pageContains(new RegExp(/Logout Successful/, 'i')), 'logout')
  })
})

import { p as peekMeta, c as createCache, g as getValue, I as Input, T as Textarea, a as componentCapabilities, C as Component, b as getComponentTemplate, s as setComponentManager, d as setComponentTemplate, e as guidFor, M as MutableArray, E as EmberObject, f as setCustomTagFor, P as PROPERTY_DID_CHANGE, h as get, o as objectAt, r as replace, i as consumeTag, j as arrayContentWillChange, k as arrayContentDidChange, l as addArrayObserver, m as removeArrayObserver, v as validateTag, t as tagFor, n as valueForTag, q as isObject, u as combine, w as tagForProperty, x as alias, y as ENV, z as context, A as getENV, B as getLookup, D as global$1, F as setLookup, G as Meta, U as UNDEFINED, H as counters, J as meta, K as setMeta, L as set, N as ASYNC_OBSERVERS, O as ComputedDescriptor, Q as ComputedProperty, R as DEBUG_INJECTION_FUNCTIONS, S as Libraries, V as NAMESPACES, W as NAMESPACES_BY_ID, X as PROXY_CONTENT, Y as SYNC_OBSERVERS, Z as TrackedDescriptor, _ as _getPath, $ as _getProp, a0 as _setProp, a1 as activateObserver, a2 as addListener, a3 as addNamespace, a4 as addObserver, a5 as autoComputed, a6 as beginPropertyChanges, a7 as changeProperties, a8 as computed, a9 as defineDecorator, aa as defineProperty, ab as defineValue, ac as descriptorForDecorator, ad as descriptorForProperty, ae as endPropertyChanges, af as expandProperties, ag as findNamespace, ah as findNamespaces, ai as flushAsyncObservers, aj as getProperties, ak as hasListeners, al as hasUnknownProperty, am as inject, an as isClassicDecorator, ao as isComputed, ap as isConst, aq as isElementDescriptor, ar as isSearchDisabled, as as LIBRARIES, at as makeComputedDecorator, au as markObjectAsDirty, av as nativeDescDecorator, aw as notifyPropertyChange, ax as on, ay as processAllNamespaces, az as processNamespace, aA as removeListener, aB as removeNamespace, aC as removeObserver, aD as replaceInNativeArray, aE as revalidateObservers, aF as sendEvent, aG as setClassicDecorator, aH as setSearchDisabled, aI as setProperties, aJ as setUnprocessedMixins, aK as tagForObject, aL as tracked, aM as trySet, aN as ActionHandler, aO as Comparable, aP as ContainerProxyMixin, aQ as MutableEnumerable, aR as RSVP$1, aS as RegistryProxyMixin, aT as TargetActionSupport, aU as ProxyMixin, aV as contentFor, aW as onerrorDefault, aX as Cache, aY as GUID_KEY, aZ as ROOT, a_ as checkHasSuper, a$ as makeDictionary, b0 as enumerableSymbol, b1 as generateGuid, b2 as getDebugName$1, b3 as getName, b4 as intern, b5 as isInternalSymbol, b6 as isProxy, b7 as lookupDescriptor, b8 as observerListenerMetaFor, b9 as setListeners, ba as setName, bb as setObservers, bc as setProxy, bd as setWithMandatorySetter, be as setupMandatorySetter, bf as symbol, bg as teardownMandatorySetter, bh as toString, bi as uuid, bj as wrap, bk as ActionSupport, bl as ComponentLookup, bm as CoreView, bn as EventDispatcher, bo as MUTABLE_CELL, bp as states, bq as addChildView, br as clearElementView, bs as clearViewElement, bt as constructStyleDeprecationMessage, bu as getChildViews, bv as getElementView, bw as getRootViews, bx as getViewBoundingClientRect, by as getViewBounds, bz as getViewClientRects, bA as getViewElement, bB as getViewId, bC as isSimpleClick, bD as setElementView, bE as setViewElement, bF as Mixin, bG as FrameworkObject, bH as EventTarget, bI as Promise$1, bJ as all, bK as allSettled, bL as asap, bM as async, bN as cast, bO as configure, bP as RSVP, bQ as defer, bR as denodeify, bS as filter, bT as hash, bU as hashSettled, bV as map, bW as off, bX as on$1, bY as race, bZ as reject, b_ as resolve, b$ as rethrow } from './main-DuaEQ8B1.js';
export { c0 as Application, c1 as ApplicationNamespace, c2 as Array, c3 as Controller, c4 as Debug, c5 as EmberDestroyable, c6 as EmberObject, c7 as EnumerableMutable, c8 as GlimmerComponent, c9 as GlimmerManager, ca as GlimmerReference, cb as GlimmerRuntime, cc as GlimmerUtil, cd as GlimmerValidator, ce as Instrumentation, c6 as Object, cf as ObjectCore, cg as ObjectEvented, ch as ObjectObservable, ci as Owner, cj as Runloop, ck as Service, cl as VERSION } from './main-DuaEQ8B1.js';

function getCachedValueFor(obj, key) {
  let meta = peekMeta(obj);
  if (meta) {
    return meta.valueFor(key);
  } else {
    return undefined;
  }
}

/**
  Checks to see if the `methodName` exists on the `obj`.

  ```javascript
  let foo = { bar: function() { return 'bar'; }, baz: null };

  Ember.canInvoke(foo, 'bar'); // true
  Ember.canInvoke(foo, 'baz'); // false
  Ember.canInvoke(foo, 'bat'); // false
  ```

  @method canInvoke
  @for Ember
  @param {Object} obj The object to check for the method
  @param {String} methodName The method name to check for
  @return {Boolean}
  @private
*/
function canInvoke(obj, methodName) {
  return obj != null && typeof obj[methodName] === 'function';
}

// NOTE: copied from: https://github.com/glimmerjs/glimmer.js/pull/358
// Both glimmerjs/glimmer.js and emberjs/ember.js have the exact same implementation
// of @cached, so any changes made to one should also be made to the other

const cached = (...args) => {
  const [target, key, descriptor] = args;
  const caches = new WeakMap();
  const getter = descriptor.get;
  descriptor.get = function () {
    if (!caches.has(this)) {
      caches.set(this, createCache(getter.bind(this)));
    }
    return getValue(caches.get(this));
  };
};

const index$7 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  Input,
  Textarea,
  capabilities: componentCapabilities,
  default: Component,
  getComponentTemplate,
  setComponentManager,
  setComponentTemplate
}, Symbol.toStringTag, { value: 'Module' }));

const internals = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  cacheFor: getCachedValueFor,
  guidFor
}, Symbol.toStringTag, { value: 'Module' }));

const mutable = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: MutableArray
}, Symbol.toStringTag, { value: 'Module' }));

const ARRAY_OBSERVER_MAPPING = {
  willChange: '_arrangedContentArrayWillChange',
  didChange: '_arrangedContentArrayDidChange'
};
function customTagForArrayProxy(proxy, key) {
  if (key === '[]') {
    proxy._revalidate();
    return proxy._arrTag;
  } else if (key === 'length') {
    proxy._revalidate();
    return proxy._lengthTag;
  }
  return tagFor(proxy, key);
}

/**
  An ArrayProxy wraps any other object that implements `Array` and/or
  `MutableArray,` forwarding all requests. This makes it very useful for
  a number of binding use cases or other cases where being able to swap
  out the underlying array is useful.

  A simple example of usage:

  ```javascript
  import { A } from '@ember/array';
  import ArrayProxy from '@ember/array/proxy';

  let pets = ['dog', 'cat', 'fish'];
  let ap = ArrayProxy.create({ content: A(pets) });

  ap.get('firstObject');                        // 'dog'
  ap.set('content', ['amoeba', 'paramecium']);
  ap.get('firstObject');                        // 'amoeba'
  ```

  This class can also be useful as a layer to transform the contents of
  an array, as they are accessed. This can be done by overriding
  `objectAtContent`:

  ```javascript
  import { A } from '@ember/array';
  import ArrayProxy from '@ember/array/proxy';

  let pets = ['dog', 'cat', 'fish'];
  let ap = ArrayProxy.create({
      content: A(pets),
      objectAtContent: function(idx) {
          return this.get('content').objectAt(idx).toUpperCase();
      }
  });

  ap.get('firstObject'); // . 'DOG'
  ```

  When overriding this class, it is important to place the call to
  `_super` *after* setting `content` so the internal observers have
  a chance to fire properly:

  ```javascript
  import { A } from '@ember/array';
  import ArrayProxy from '@ember/array/proxy';

  export default ArrayProxy.extend({
    init() {
      this.set('content', A(['dog', 'cat', 'fish']));
      this._super(...arguments);
    }
  });
  ```

  @class ArrayProxy
  @extends EmberObject
  @uses MutableArray
  @public
*/

class ArrayProxy extends EmberObject {
  /*
    `this._objectsDirtyIndex` determines which indexes in the `this._objects`
    cache are dirty.
     If `this._objectsDirtyIndex === -1` then no indexes are dirty.
    Otherwise, an index `i` is dirty if `i >= this._objectsDirtyIndex`.
     Calling `objectAt` with a dirty index will cause the `this._objects`
    cache to be recomputed.
  */
  /** @internal */
  _objectsDirtyIndex = 0;
  /** @internal */
  _objects = null;

  /** @internal */
  _lengthDirty = true;
  /** @internal */
  _length = 0;

  /** @internal */
  _arrangedContent = null;
  /** @internal */
  _arrangedContentIsUpdating = false;
  /** @internal */
  _arrangedContentTag = null;
  /** @internal */
  _arrangedContentRevision = null;
  /** @internal */
  _lengthTag = null;
  /** @internal */
  _arrTag = null;
  init(props) {
    super.init(props);
    setCustomTagFor(this, customTagForArrayProxy);
  }
  [PROPERTY_DID_CHANGE]() {
    this._revalidate();
  }
  willDestroy() {
    this._removeArrangedContentArrayObserver();
  }
  objectAtContent(idx) {
    let arrangedContent = get(this, 'arrangedContent');
    return objectAt(arrangedContent, idx);
  }

  // See additional docs for `replace` from `MutableArray`:
  // https://api.emberjs.com/ember/release/classes/MutableArray/methods/replace?anchor=replace
  replace(idx, amt, objects) {
    this.replaceContent(idx, amt, objects);
  }
  replaceContent(idx, amt, objects) {
    let content = get(this, 'content');
    replace(content, idx, amt, objects);
  }

  // Overriding objectAt is not supported.
  objectAt(idx) {
    this._revalidate();
    if (this._objects === null) {
      this._objects = [];
    }
    if (this._objectsDirtyIndex !== -1 && idx >= this._objectsDirtyIndex) {
      let arrangedContent = get(this, 'arrangedContent');
      if (arrangedContent) {
        let length = this._objects.length = get(arrangedContent, 'length');
        for (let i = this._objectsDirtyIndex; i < length; i++) {
          // SAFETY: This is expected to only ever return an instance of T. In other words, there should
          // be no gaps in the array. Unfortunately, we can't actually assert for it since T could include
          // any types, including null or undefined.
          this._objects[i] = this.objectAtContent(i);
        }
      } else {
        this._objects.length = 0;
      }
      this._objectsDirtyIndex = -1;
    }
    return this._objects[idx];
  }

  // Overriding length is not supported.
  get length() {
    this._revalidate();
    if (this._lengthDirty) {
      let arrangedContent = get(this, 'arrangedContent');
      this._length = arrangedContent ? get(arrangedContent, 'length') : 0;
      this._lengthDirty = false;
    }
    consumeTag(this._lengthTag);
    return this._length;
  }
  set length(value) {
    let length = this.length;
    let removedCount = length - value;
    let added;
    if (removedCount === 0) {
      return;
    } else if (removedCount < 0) {
      added = new Array(-removedCount);
      removedCount = 0;
    }
    let content = get(this, 'content');
    if (content) {
      replace(content, value, removedCount, added);
      this._invalidate();
    }
  }
  _updateArrangedContentArray(arrangedContent) {
    let oldLength = this._objects === null ? 0 : this._objects.length;
    let newLength = arrangedContent ? get(arrangedContent, 'length') : 0;
    this._removeArrangedContentArrayObserver();
    arrayContentWillChange(this, 0, oldLength, newLength);
    this._invalidate();
    arrayContentDidChange(this, 0, oldLength, newLength, false);
    this._addArrangedContentArrayObserver(arrangedContent);
  }
  _addArrangedContentArrayObserver(arrangedContent) {
    if (arrangedContent && !arrangedContent.isDestroyed) {
      addArrayObserver(arrangedContent, this, ARRAY_OBSERVER_MAPPING);
      this._arrangedContent = arrangedContent;
    }
  }
  _removeArrangedContentArrayObserver() {
    if (this._arrangedContent) {
      removeArrayObserver(this._arrangedContent, this, ARRAY_OBSERVER_MAPPING);
    }
  }
  _arrangedContentArrayWillChange() {}
  _arrangedContentArrayDidChange(_proxy, idx, removedCnt, addedCnt) {
    arrayContentWillChange(this, idx, removedCnt, addedCnt);
    let dirtyIndex = idx;
    if (dirtyIndex < 0) {
      let length = get(this._arrangedContent, 'length');
      dirtyIndex += length + removedCnt - addedCnt;
    }
    if (this._objectsDirtyIndex === -1 || this._objectsDirtyIndex > dirtyIndex) {
      this._objectsDirtyIndex = dirtyIndex;
    }
    this._lengthDirty = true;
    arrayContentDidChange(this, idx, removedCnt, addedCnt, false);
  }
  _invalidate() {
    this._objectsDirtyIndex = 0;
    this._lengthDirty = true;
  }
  _revalidate() {
    if (this._arrangedContentIsUpdating === true) return;
    if (this._arrangedContentTag === null || !validateTag(this._arrangedContentTag, this._arrangedContentRevision)) {
      let arrangedContent = this.get('arrangedContent');
      if (this._arrangedContentTag === null) {
        // This is the first time the proxy has been setup, only add the observer
        // don't trigger any events
        this._addArrangedContentArrayObserver(arrangedContent);
      } else {
        this._arrangedContentIsUpdating = true;
        this._updateArrangedContentArray(arrangedContent);
        this._arrangedContentIsUpdating = false;
      }
      let arrangedContentTag = this._arrangedContentTag = tagFor(this, 'arrangedContent');
      this._arrangedContentRevision = valueForTag(this._arrangedContentTag);
      if (isObject(arrangedContent)) {
        this._lengthTag = combine([arrangedContentTag, tagForProperty(arrangedContent, 'length')]);
        this._arrTag = combine([arrangedContentTag, tagForProperty(arrangedContent, '[]')]);
      } else {
        this._lengthTag = this._arrTag = arrangedContentTag;
      }
    }
  }
}
ArrayProxy.reopen(MutableArray, {
  arrangedContent: alias('content')
});

const proxy$1 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: ArrayProxy
}, Symbol.toStringTag, { value: 'Module' }));

const index$6 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  ENV,
  context,
  getENV,
  getLookup,
  global: global$1,
  setLookup
}, Symbol.toStringTag, { value: 'Module' }));

const index$5 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  Meta,
  UNDEFINED,
  counters,
  meta,
  peekMeta,
  setMeta
}, Symbol.toStringTag, { value: 'Module' }));

/**
@module ember
*/

function deprecateProperty(object, deprecatedKey, newKey, options) {
  Object.defineProperty(object, deprecatedKey, {
    configurable: true,
    enumerable: false,
    set(value) {
      set(this, newKey, value);
    },
    get() {
      return get(this, newKey);
    }
  });
}
const EACH_PROXIES = new WeakMap();
function eachProxyArrayWillChange(array, idx, removedCnt, addedCnt) {
  let eachProxy = EACH_PROXIES.get(array);
  if (eachProxy !== undefined) {
    eachProxy.arrayWillChange(array, idx, removedCnt, addedCnt);
  }
}
function eachProxyArrayDidChange(array, idx, removedCnt, addedCnt) {
  let eachProxy = EACH_PROXIES.get(array);
  if (eachProxy !== undefined) {
    eachProxy.arrayDidChange(array, idx, removedCnt, addedCnt);
  }
}

const index$4 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  ASYNC_OBSERVERS,
  ComputedDescriptor,
  ComputedProperty,
  DEBUG_INJECTION_FUNCTIONS,
  Libraries,
  NAMESPACES,
  NAMESPACES_BY_ID,
  PROPERTY_DID_CHANGE,
  PROXY_CONTENT,
  SYNC_OBSERVERS,
  TrackedDescriptor,
  _getPath,
  _getProp,
  _setProp,
  activateObserver,
  addArrayObserver,
  addListener,
  addNamespace,
  addObserver,
  alias,
  arrayContentDidChange,
  arrayContentWillChange,
  autoComputed,
  beginPropertyChanges,
  cached,
  changeProperties,
  computed,
  createCache,
  defineDecorator,
  defineProperty,
  defineValue,
  deprecateProperty,
  descriptorForDecorator,
  descriptorForProperty,
  eachProxyArrayDidChange,
  eachProxyArrayWillChange,
  endPropertyChanges,
  expandProperties,
  findNamespace,
  findNamespaces,
  flushAsyncObservers,
  get,
  getCachedValueFor,
  getProperties,
  getValue,
  hasListeners,
  hasUnknownProperty,
  inject,
  isClassicDecorator,
  isComputed,
  isConst,
  isElementDescriptor,
  isNamespaceSearchDisabled: isSearchDisabled,
  libraries: LIBRARIES,
  makeComputedDecorator,
  markObjectAsDirty,
  nativeDescDecorator,
  notifyPropertyChange,
  objectAt,
  on,
  processAllNamespaces,
  processNamespace,
  removeArrayObserver,
  removeListener,
  removeNamespace,
  removeObserver,
  replace,
  replaceInNativeArray,
  revalidateObservers,
  sendEvent,
  set,
  setClassicDecorator,
  setNamespaceSearchDisabled: setSearchDisabled,
  setProperties,
  setUnprocessedMixins,
  tagForObject,
  tagForProperty,
  tracked,
  trySet
}, Symbol.toStringTag, { value: 'Module' }));

const index$3 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  ActionHandler,
  Comparable,
  ContainerProxyMixin,
  MutableEnumerable,
  RSVP: RSVP$1,
  RegistryProxyMixin,
  TargetActionSupport,
  _ProxyMixin: ProxyMixin,
  _contentFor: contentFor,
  onerrorDefault
}, Symbol.toStringTag, { value: 'Module' }));

const index$2 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  Cache,
  GUID_KEY,
  ROOT,
  canInvoke,
  checkHasSuper,
  dictionary: makeDictionary,
  enumerableSymbol,
  generateGuid,
  getDebugName: getDebugName$1,
  getName,
  guidFor,
  intern,
  isInternalSymbol,
  isObject,
  isProxy,
  lookupDescriptor,
  observerListenerMetaFor,
  setListeners,
  setName,
  setObservers,
  setProxy,
  setWithMandatorySetter,
  setupMandatorySetter,
  symbol,
  teardownMandatorySetter,
  toString,
  uuid,
  wrap
}, Symbol.toStringTag, { value: 'Module' }));

const index$1 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  ActionSupport,
  ComponentLookup,
  CoreView,
  EventDispatcher,
  MUTABLE_CELL,
  ViewStates: states,
  addChildView,
  clearElementView,
  clearViewElement,
  constructStyleDeprecationMessage,
  getChildViews,
  getElementView,
  getRootViews,
  getViewBoundingClientRect,
  getViewBounds,
  getViewClientRects,
  getViewElement,
  getViewId,
  isSimpleClick,
  setElementView,
  setViewElement
}, Symbol.toStringTag, { value: 'Module' }));

/**
  @module @ember/object/promise-proxy-mixin
*/

function tap(proxy, promise) {
  setProperties(proxy, {
    isFulfilled: false,
    isRejected: false
  });
  return promise.then(value => {
    if (!proxy.isDestroyed && !proxy.isDestroying) {
      setProperties(proxy, {
        content: value,
        isFulfilled: true
      });
    }
    return value;
  }, reason => {
    if (!proxy.isDestroyed && !proxy.isDestroying) {
      setProperties(proxy, {
        reason,
        isRejected: true
      });
    }
    throw reason;
  }, 'Ember: PromiseProxy');
}

/**
  A low level mixin making ObjectProxy promise-aware.

  ```javascript
  import { resolve } from 'rsvp';
  import $ from 'jquery';
  import ObjectProxy from '@ember/object/proxy';
  import PromiseProxyMixin from '@ember/object/promise-proxy-mixin';

  let ObjectPromiseProxy = ObjectProxy.extend(PromiseProxyMixin);

  let proxy = ObjectPromiseProxy.create({
    promise: resolve($.getJSON('/some/remote/data.json'))
  });

  proxy.then(function(json){
     // the json
  }, function(reason) {
     // the reason why you have no json
  });
  ```

  the proxy has bindable attributes which
  track the promises life cycle

  ```javascript
  proxy.get('isPending')   //=> true
  proxy.get('isSettled')  //=> false
  proxy.get('isRejected')  //=> false
  proxy.get('isFulfilled') //=> false
  ```

  When the $.getJSON completes, and the promise is fulfilled
  with json, the life cycle attributes will update accordingly.
  Note that $.getJSON doesn't return an ECMA specified promise,
  it is useful to wrap this with an `RSVP.resolve` so that it behaves
  as a spec compliant promise.

  ```javascript
  proxy.get('isPending')   //=> false
  proxy.get('isSettled')   //=> true
  proxy.get('isRejected')  //=> false
  proxy.get('isFulfilled') //=> true
  ```

  As the proxy is an ObjectProxy, and the json now its content,
  all the json properties will be available directly from the proxy.

  ```javascript
  // Assuming the following json:
  {
    firstName: 'Stefan',
    lastName: 'Penner'
  }

  // both properties will accessible on the proxy
  proxy.get('firstName') //=> 'Stefan'
  proxy.get('lastName')  //=> 'Penner'
  ```

  @class PromiseProxyMixin
  @public
*/

const PromiseProxyMixin = Mixin.create({
  reason: null,
  isPending: computed('isSettled', function () {
    return !get(this, 'isSettled');
  }).readOnly(),
  isSettled: computed('isRejected', 'isFulfilled', function () {
    return get(this, 'isRejected') || get(this, 'isFulfilled');
  }).readOnly(),
  isRejected: false,
  isFulfilled: false,
  promise: computed({
    get() {
      throw new Error("PromiseProxy's promise must be set");
    },
    set(_key, promise) {
      return tap(this, promise);
    }
  }),
  then: promiseAlias('then'),
  catch: promiseAlias('catch'),
  finally: promiseAlias('finally')
});
function promiseAlias(name) {
  return function (...args) {
    let promise = get(this, 'promise');

    // We need this cast because `Parameters` is deferred so that it is not
    // possible for TS to see it will always produce the right type. However,
    // since `AnyFn` has a rest type, it is allowed. See discussion on [this
    // issue](https://github.com/microsoft/TypeScript/issues/47615).
    return promise[name](...args);
  };
}

const promiseProxyMixin = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: PromiseProxyMixin
}, Symbol.toStringTag, { value: 'Module' }));

/**
@module @ember/object/proxy
*/

/**
  `ObjectProxy` forwards all properties not defined by the proxy itself
  to a proxied `content` object.

  ```javascript
  import EmberObject from '@ember/object';
  import ObjectProxy from '@ember/object/proxy';

  let exampleObject = EmberObject.create({
    name: 'Foo'
  });

  let exampleProxy = ObjectProxy.create({
    content: exampleObject
  });

  // Access and change existing properties
  exampleProxy.get('name');          // 'Foo'
  exampleProxy.set('name', 'Bar');
  exampleObject.get('name');         // 'Bar'

  // Create new 'description' property on `exampleObject`
  exampleProxy.set('description', 'Foo is a whizboo baz');
  exampleObject.get('description');  // 'Foo is a whizboo baz'
  ```

  While `content` is unset, setting a property to be delegated will throw an
  Error.

  ```javascript
  import ObjectProxy from '@ember/object/proxy';

  let exampleProxy = ObjectProxy.create({
    content: null,
    flag: null
  });
  exampleProxy.set('flag', true);
  exampleProxy.get('flag');         // true
  exampleProxy.get('foo');          // undefined
  exampleProxy.set('foo', 'data');  // throws Error
  ```

  Delegated properties can be bound to and will change when content is updated.

  Computed properties on the proxy itself can depend on delegated properties.

  ```javascript
  import { computed } from '@ember/object';
  import ObjectProxy from '@ember/object/proxy';

  class ProxyWithComputedProperty extends ObjectProxy {
    @computed('firstName', 'lastName')
    get fullName() {
      var firstName = this.get('firstName'),
          lastName = this.get('lastName');
      if (firstName && lastName) {
        return firstName + ' ' + lastName;
      }
      return firstName || lastName;
    }
  }

  let exampleProxy = ProxyWithComputedProperty.create();

  exampleProxy.get('fullName');  // undefined
  exampleProxy.set('content', {
    firstName: 'Tom', lastName: 'Dale'
  }); // triggers property change for fullName on proxy

  exampleProxy.get('fullName');  // 'Tom Dale'
  ```

  @class ObjectProxy
  @extends EmberObject
  @uses Ember.ProxyMixin
  @public
*/

// eslint-disable-next-line @typescript-eslint/no-unused-vars
class ObjectProxy extends FrameworkObject {}
ObjectProxy.PrototypeMixin.reopen(ProxyMixin);

const proxy = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: ObjectProxy
}, Symbol.toStringTag, { value: 'Module' }));

const index = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  EventTarget,
  Promise: Promise$1,
  all,
  allSettled,
  asap,
  async,
  cast,
  configure,
  default: RSVP,
  defer,
  denodeify,
  filter,
  hash,
  hashSettled,
  map,
  off,
  on: on$1,
  race,
  reject,
  resolve,
  rethrow
}, Symbol.toStringTag, { value: 'Module' }));

export { mutable as ArrayMutable, proxy$1 as ArrayProxy, index$7 as Component, index$6 as InternalsEnvironment, index$5 as InternalsMeta, index$4 as InternalsMetal, index$3 as InternalsRuntime, index$2 as InternalsUtils, index$1 as InternalsViews, internals as ObjectInternals, promiseProxyMixin as ObjectPromiseProxyMixin, proxy as ObjectProxy, index as RSVP };

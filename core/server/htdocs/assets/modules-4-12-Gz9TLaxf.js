import { p as peekMeta, c as createCache, g as getValue, I as Input, T as Textarea, a as componentCapabilities, C as Component, b as getComponentTemplate, s as setComponentManager, d as setComponentTemplate, r as registerDestructor$1, u as unregisterDestructor$1, e as assertDestroyablesDestroyed, f as associateDestroyableChild, h as destroy, i as enableDestroyableTracking, j as isDestroyed, k as isDestroying, l as guidFor, M as MutableArray, E as EmberObject, m as setCustomTagFor, P as PROPERTY_DID_CHANGE, n as get, o as objectAt, q as replace, t as consumeTag, v as arrayContentWillChange, w as arrayContentDidChange, x as addArrayObserver, y as removeArrayObserver, z as validateTag, A as tagFor, B as valueForTag, D as isObject, F as combine, G as tagForProperty, H as alias, J as ENV, K as context, L as getENV, N as getLookup, O as global$1, Q as setLookup, R as Meta, U as UNDEFINED, S as counters, V as meta, W as setMeta, X as set, Y as ASYNC_OBSERVERS, Z as ComputedDescriptor, _ as ComputedProperty, $ as DEBUG_INJECTION_FUNCTIONS, a0 as Libraries, a1 as NAMESPACES, a2 as NAMESPACES_BY_ID, a3 as PROXY_CONTENT, a4 as SYNC_OBSERVERS, a5 as TrackedDescriptor, a6 as _getPath, a7 as _getProp, a8 as _setProp, a9 as activateObserver, aa as addListener, ab as addNamespace, ac as addObserver, ad as autoComputed, ae as beginPropertyChanges, af as changeProperties, ag as computed, ah as defineDecorator, ai as defineProperty, aj as defineValue, ak as descriptorForDecorator, al as descriptorForProperty, am as endPropertyChanges, an as expandProperties, ao as findNamespace, ap as findNamespaces, aq as flushAsyncObservers, ar as getProperties, as as hasListeners, at as hasUnknownProperty, au as inject, av as isClassicDecorator, aw as isComputed, ax as isConst, ay as isElementDescriptor, az as isSearchDisabled, aA as LIBRARIES, aB as makeComputedDecorator, aC as markObjectAsDirty, aD as nativeDescDecorator, aE as notifyPropertyChange, aF as on, aG as processAllNamespaces, aH as processNamespace, aI as removeListener, aJ as removeNamespace, aK as removeObserver, aL as replaceInNativeArray, aM as revalidateObservers, aN as sendEvent, aO as setClassicDecorator, aP as setSearchDisabled, aQ as setProperties, aR as setUnprocessedMixins, aS as tagForObject, aT as tracked, aU as trySet, aV as ActionHandler, aW as Comparable, aX as ContainerProxyMixin, aY as MutableEnumerable, aZ as RSVP$1, a_ as RegistryProxyMixin, a$ as TargetActionSupport, b0 as ProxyMixin, b1 as contentFor, b2 as onerrorDefault, b3 as Cache, b4 as GUID_KEY, b5 as ROOT, b6 as checkHasSuper, b7 as makeDictionary, b8 as enumerableSymbol, b9 as generateGuid, ba as getDebugName$1, bb as getName, bc as intern, bd as isInternalSymbol, be as isProxy, bf as lookupDescriptor, bg as observerListenerMetaFor, bh as setListeners, bi as setName, bj as setObservers, bk as setProxy, bl as setWithMandatorySetter, bm as setupMandatorySetter, bn as symbol, bo as teardownMandatorySetter, bp as toString, bq as uuid, br as wrap, bs as ActionSupport, bt as ComponentLookup, bu as CoreView, bv as EventDispatcher, bw as MUTABLE_CELL, bx as states, by as addChildView, bz as clearElementView, bA as clearViewElement, bB as constructStyleDeprecationMessage, bC as getChildViews, bD as getElementView, bE as getRootViews, bF as getViewBoundingClientRect, bG as getViewBounds, bH as getViewClientRects, bI as getViewElement, bJ as getViewId, bK as isSimpleClick, bL as setElementView, bM as setViewElement, bN as Mixin, bO as FrameworkObject, bP as EventTarget, bQ as Promise$1, bR as all, bS as allSettled, bT as asap, bU as async, bV as cast, bW as configure, bX as RSVP, bY as defer, bZ as denodeify, b_ as filter, b$ as hash, c0 as hashSettled, c1 as map, c2 as off, c3 as on$1, c4 as race, c5 as reject, c6 as resolve, c7 as rethrow } from './main-DNeaH_Eq.js';
export { c8 as Application, c9 as ApplicationNamespace, ca as Array, cb as Controller, cc as Debug, cd as EmberObject, ce as EnumerableMutable, cf as GlimmerComponent, cg as GlimmerManager, ch as GlimmerReference, ci as GlimmerRuntime, cj as GlimmerUtil, ck as GlimmerValidator, cl as Instrumentation, cd as Object, cm as ObjectCore, cn as ObjectEvented, co as ObjectObservable, cp as Owner, cq as Runloop, cr as Service, cs as VERSION } from './main-DNeaH_Eq.js';

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

const index$8 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  Input,
  Textarea,
  capabilities: componentCapabilities,
  default: Component,
  getComponentTemplate,
  setComponentManager,
  setComponentTemplate
}, Symbol.toStringTag, { value: 'Module' }));

/**
  Ember manages the lifecycles and lifetimes of many built in constructs, such
  as components, and does so in a hierarchical way - when a parent component is
  destroyed, all of its children are destroyed as well.

  This destroyables API exposes the basic building blocks for destruction:

  * registering a function to be ran when an object is destroyed
  * checking if an object is in a destroying state
  * associate an object as a child of another so that the child object will be destroyed
    when the associated parent object is destroyed.

  @module @ember/destroyable
  @public
*/

/**
  This function is used to associate a destroyable object with a parent. When the parent
  is destroyed, all registered children will also be destroyed.

  ```js
  class CustomSelect extends Component {
    constructor(...args) {
      super(...args);

      // obj is now a child of the component. When the component is destroyed,
      // obj will also be destroyed, and have all of its destructors triggered.
      this.obj = associateDestroyableChild(this, {});
    }
  }
  ```

  Returns the associated child for convenience.

  @method associateDestroyableChild
  @for @ember/destroyable
  @param {Object|Function} parent the destroyable to entangle the child destroyables lifetime with
  @param {Object|Function} child the destroyable to be entangled with the parents lifetime
  @returns {Object|Function} the child argument
  @static
  @public
*/

/**
 Receives a destroyable, and returns true if the destroyable has begun destroying. Otherwise returns
 false.

  ```js
  let obj = {};
  isDestroying(obj); // false
  destroy(obj);
  isDestroying(obj); // true
  // ...sometime later, after scheduled destruction
  isDestroyed(obj); // true
  isDestroying(obj); // true
  ```

  @method isDestroying
  @for @ember/destroyable
  @param {Object|Function} destroyable the object to check
  @returns {Boolean}
  @static
  @public
*/

/**
  Receives a destroyable, and returns true if the destroyable has finished destroying. Otherwise
  returns false.

  ```js
  let obj = {};

  isDestroyed(obj); // false
  destroy(obj);

  // ...sometime later, after scheduled destruction

  isDestroyed(obj); // true
  ```

  @method isDestroyed
  @for @ember/destroyable
  @param {Object|Function} destroyable the object to check
  @returns {Boolean}
  @static
  @public
*/

/**
  Initiates the destruction of a destroyable object. It runs all associated destructors, and then
  destroys all children recursively.

  ```js
  let obj = {};

  registerDestructor(obj, () => console.log('destroyed!'));

  destroy(obj); // this will schedule the destructor to be called

  // ...some time later, during scheduled destruction

  // destroyed!
  ```

  Destruction via `destroy()` follows these steps:

  1, Mark the destroyable such that `isDestroying(destroyable)` returns `true`
  2, Call `destroy()` on each of the destroyable's associated children
  3, Schedule calling the destroyable's destructors
  4, Schedule setting destroyable such that `isDestroyed(destroyable)` returns `true`

  This results in the entire tree of destroyables being first marked as destroying,
  then having all of their destructors called, and finally all being marked as isDestroyed.
  There won't be any in between states where some items are marked as `isDestroying` while
  destroying, while others are not.

  @method destroy
  @for @ember/destroyable
  @param {Object|Function} destroyable the object to destroy
  @static
  @public
*/

/**
  This function asserts that all objects which have associated destructors or associated children
  have been destroyed at the time it is called. It is meant to be a low level hook that testing
  frameworks can use to hook into and validate that all destroyables have in fact been destroyed.

  This function requires that `enableDestroyableTracking` was called previously, and is only
  available in non-production builds.

  @method assertDestroyablesDestroyed
  @for @ember/destroyable
  @static
  @public
*/

/**
  This function instructs the destroyable system to keep track of all destroyables (their
  children, destructors, etc). This enables a future usage of `assertDestroyablesDestroyed`
  to be used to ensure that all destroyable tasks (registered destructors and associated children)
  have completed when `assertDestroyablesDestroyed` is called.

  @method enableDestroyableTracking
  @for @ember/destroyable
  @static
  @public
*/

/**
  Receives a destroyable object and a destructor function, and associates the
  function with it. When the destroyable is destroyed with destroy, or when its
  parent is destroyed, the destructor function will be called.

  ```js
  import Component from '@glimmer/component';
  import { registerDestructor } from '@ember/destroyable';

  class Modal extends Component {
    @service resize;

    constructor(...args) {
      super(...args);

      this.resize.register(this, this.layout);

      registerDestructor(this, () => this.resize.unregister(this));
    }
  }
  ```

  Multiple destructors can be associated with a given destroyable, and they can be
  associated over time, allowing libraries to dynamically add destructors as needed.
  `registerDestructor` also returns the associated destructor function, for convenience.

  The destructor function is passed a single argument, which is the destroyable itself.
  This allows the function to be reused multiple times for many destroyables, rather
  than creating a closure function per destroyable.

  ```js
  import Component from '@glimmer/component';
  import { registerDestructor } from '@ember/destroyable';

  function unregisterResize(instance) {
    instance.resize.unregister(instance);
  }

  class Modal extends Component {
    @service resize;

    constructor(...args) {
      super(...args);

      this.resize.register(this, this.layout);

      registerDestructor(this, unregisterResize);
    }
  }
  ```

  @method registerDestructor
  @for @ember/destroyable
  @param {Object|Function} destroyable the destroyable to register the destructor function with
  @param {Function} destructor the destructor to run when the destroyable object is destroyed
  @static
  @public
*/
function registerDestructor(destroyable, destructor) {
  return registerDestructor$1(destroyable, destructor);
}

/**
  Receives a destroyable and a destructor function, and de-associates the destructor
  from the destroyable.

  ```js
  import Component from '@glimmer/component';
  import { registerDestructor, unregisterDestructor } from '@ember/destroyable';

  class Modal extends Component {
    @service modals;

    constructor(...args) {
      super(...args);

      this.modals.add(this);

      this.modalDestructor = registerDestructor(this, () => this.modals.remove(this));
    }

    @action pinModal() {
      unregisterDestructor(this, this.modalDestructor);
    }
  }
  ```

  @method unregisterDestructor
  @for @ember/destroyable
  @param {Object|Function} destroyable the destroyable to unregister the destructor function from
  @param {Function} destructor the destructor to remove from the destroyable
  @static
  @public
*/
function unregisterDestructor(destroyable, destructor) {
  return unregisterDestructor$1(destroyable, destructor);
}

const index$7 = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  assertDestroyablesDestroyed,
  associateDestroyableChild,
  destroy,
  enableDestroyableTracking,
  isDestroyed,
  isDestroying,
  registerDestructor,
  unregisterDestructor
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

export { mutable as ArrayMutable, proxy$1 as ArrayProxy, index$8 as Component, index$7 as EmberDestroyable, index$6 as InternalsEnvironment, index$5 as InternalsMeta, index$4 as InternalsMetal, index$3 as InternalsRuntime, index$2 as InternalsUtils, index$1 as InternalsViews, internals as ObjectInternals, promiseProxyMixin as ObjectPromiseProxyMixin, proxy as ObjectProxy, index as RSVP };

/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
// A reactive state management library
// Features:
//  - Fine grained dependency tracking and incremental computation
//  - Automatic subscription management
//  - Support for families that are similar other than an argument
// TODO: Better lifetime management (auto-disposal/pausing when no listeners)
// TODO: Fix cancelation
// TODO: Overrides - via implicits?
module reactives
import std/core/unsafe

// A reactor is a fine-grained piece of state, with dependency tracking and incremental computation
// A reactor notifies dependencies of changes in its state
//
// Holds 
//  - current state of a reactive element
//  - listeners to call when the state changes 
//  - its own continuation 
//  - cancelations to run when previous dependencies change
//  - a name for debugging
// Can 
//  - emit a value 
//  - watch other reactives
//  - add general listeners with managed subscriptions
//  - add cancelations to run when the continuation needs to be rerun
//  - pause and unpause the reactor
//  - restart or reset the reactor (restart will also cause it to get the initial state, reset acts like no one cares about it anymore)
//  - get the current state
// 
// The reactor is not exposed outside this module, and is not meant to be used directly.
// 
// Instead there are wrappers that expose the methods while helping manage subscriptions etc.
// - rref<a>: a reactor reference (self-reference), let's you manage the state of the reactor, and add subscriptions (which are automatically tracked)
// - reactive<a>: a reference (outside the reactor) to another reactor
// - reactive-top<a>: a reference to a top level variable (delayed<react-eff,reactive<a>> due to the fact that top level variables cannot have effects)
// - reactive-family<a,b>: a family of reactives, that manage state similarly, but have different arguments (corresponds to reactive-top<a>)
// - family-instance<a,b>: a family instance, that holds the reactive and the argument (similar to rref<a>)
named effect reactor<a>
  // This is internal, keeps the initial continuation so we can reset the state
  ctl init-yield_(): () 
  // A check to see if the reactor is initialized
  fun is-initialized(): bool
  // An identifier for the reactive
  fun name_() : string
  // Emits a state value
  fun emit_(a: a): () 
  // Watches another reactor's state (immediate is whether to demand the value immediately, or wait for it to be demanded)
  ctl watch_<b,c>(p: reactive<b>, immediate: bool, sel: selector<b,c>): c
  // Listen to the reactor's state, with a debug name for the listener's computation
  // Returns a subscription handle
  fun listen_(f: listen-fn<a>, dependent: string, notify: (a) -> react-eff bool): subscription<a>
  // Cancels a subscription
  fun cancel_(s: subscription<a>): ()
  // Pauses a subscription (won't call it, but won't remove it either)
  fun pause_(s: subscription<a>): ()
  // Pauses the reactor (won't react to any changes, other than canceling and keeping track of where to resume when unpaused)
  fun pause(): ()
  // Unpauses a subscription (will call the listener again)
  fun unpause_(s: subscription<a>): ()
  // Unpauses the reactor (will react to the latest change that happened while paused)
  fun unpause(): ()
  // Restart the reactor from the beginning (will reinitialize the state)
  fun restart_(): () 
  // Reset the reactor (will clear the state, but not reinitialize it)
  fun reset_(): () 
  fun check-reset(): ()
  // Get the current state
  fun current_(): a
  // Add a cancelation function that will need to be cleaned up if the reactor resets to before this point
  // That can happen if a dependency changes before this point, or if the reactor is reset
  fun add-cancel(f: unit-cb): ()

// The basic effects needed for reactives <pure> (due to named handlers), 
//   and st<global> (due to the fact that we need to be able to mutate)
pub alias react-eff = <pure,st<global>>
// A callback type used for cancelations, initialization, and other things
pub alias unit-cb = () -> react-eff ()
// A callback type used for listeners and dependencies
pub alias listen-fn<a> = (a) -> react-eff ()

// A listener contains a function to be called when the state of the reactor changes
// The function could be a plain callback, or a continuation for another reactive (created using `watch`)
// It has a unique id, so it can be found in a list and paused and unpaused
abstract type listener<a>
  Listener(sid: int, callback: listen-fn<a>, sub: subscription<a>, paused: bool = False, notify: (a) -> react-eff bool)

abstract type selector<a,b>
  Selector(selector: a -> b, eq: (b, b) -> bool)

// A subscription is just a unique id, that can be used to cancel a listener
abstract struct subscription<a>
  sid: int
  rref: rref<a>
  canceled: ref<global,bool>

// A reactive just wraps the reactive ref, and is accessible from outside the reactor
abstract div type reactive<a>
  Reactive(rref: ev<reactor<a>>)

// A `reactive-top<a>` delays the reactive creation until it is forced
// This is needed because top level variables cannot have effects
pub alias reactive-top<a> = delayed<react-eff,reactive<a>>

// A reactive reference `rref<a>` is a reference to a reactor, that can be used to manage the state of the reactor from within
abstract div type rref<a>
  Ref(rref: ev<reactor<a>>)

// A reactive family is a family of reactives that are similar, but have different arguments
pub alias reactive-family<a,b> = ((b) -> react-eff reactive-top<a>)

// A family instance is a specific instance of a family, that holds the reactive and the argument
pub type family-instance<a,b>
  Instance(reactive: rref<a>, arg: b)

// Watching a reactive is just a matter of adding our own continuation to the other-reactive's listeners
fun reactor/watch(r: ev<reactor<a>>, other: reactive<b>, immediate: bool = True): pure b
  r.watch_(other, immediate, Selector(fn(x) x, fn(x, y) False))
fun reactor/select(r: ev<reactor<a>>, other: reactive<b>, select: b -> c, immediate: bool = True, ?(==): (c, c) -> bool): pure c
  r.watch_(other, immediate, Selector(select, ?(==)))
pub fun rref/watch(r: rref<a>, other: reactive<b>, immediate: bool = True): pure b
  r.rref.watch(other, immediate)
pub fun rref/select(r: rref<a>, other: reactive<b>, selector: b -> c, immediate: bool = True, ?(==): (c, c) -> bool): pure c
  r.rref.select(other, selector, immediate)
pub fun family/watch(r: family-instance<a,b>, other: reactive-top<c>, immediate: bool = True): react-eff c
  r.reactive.watch(other.force, immediate)
pub fun family/select(r: family-instance<a,b>, other: reactive-top<c>, selector: c -> d, immediate: bool = True, ?(==): (d, d) -> bool): react-eff d
  r.reactive.select(other.force, selector, immediate)
pub fun delayed/watch(r: rref<a>, other: reactive-top<b>, immediate: bool = True): react-eff b
  r.rref.watch(other.force, immediate)
pub fun delayed/select(r: rref<a>, other: reactive-top<b>, selector: b -> c, immediate: bool = True, ?(==): (c, c) -> bool): react-eff c
  r.rref.select(other.force, selector, immediate)

// Listening to a reactive's state updates
// 
// Involves adding our callback to the reactor's listeners
// If the reactor we want to listen to is already initialized, we can call the callback immediately if requested
// Otherwise if the reactor is not initialized, we will demand its value to cause it to be initialized (which will take care of calling our callback)
// In any case we will return a subscription
// TODO: Consider separating the initialization from getting the state
fun reactor/listen(r: ev<reactor<a>>, callback: listen-fn<a>, notify: a -> react-eff bool, immediate: bool = False, ?kk-file-line: string): react-eff subscription<a>
  val sub = r.listen_(callback, ?kk-file-line, notify) // Add the listener to the list of listeners
  if r.is-initialized() && immediate then // If initialized and immediate
    callback(r.current_()) // Call the callback with the current state
    sub
  elif immediate then
    r.current_() // Otherwise demand its current value to initialize it (which itself will call listeners)
    sub
  else sub
// When listening from another reactor, we add a cancelation to our cancelation list
// This ensures we clean up subscriptions which are no longer applicable
pub fun rref/listen(r : rref<a>, other: reactive<b>, callback: listen-fn<b>, notify: b -> react-eff bool = fn(x) True, immediate: bool = False, ?kk-file-line: string): react-eff subscription<b>
  val sub = other.rref.listen(callback, notify, immediate=immediate) // Add the listener to the list of listeners
  r.rref.add-subscription(sub)
  sub
pub fun family/listen(r : family-instance<a,b>, other: reactive-top<c>, callback: listen-fn<c>, immediate: bool = False, ?kk-file-line: string): react-eff subscription<c>
  r.reactive.listen(other.force, callback, immediate=immediate)
pub fun delayed/listen(r : rref<a>, other: reactive-top<b>, callback: listen-fn<b>, immediate: bool = False, ?kk-file-line: string): react-eff subscription<b>
  r.listen(other.force, callback, immediate=immediate)
// Same as listen, but using `on` name for better readability in some cases
pub fun rref/on(r : rref<a>, other: reactive<b>, callback: listen-fn<b>, ?kk-file-line: string): react-eff subscription<b>
  r.listen(other, callback)
pub fun family/on(r : family-instance<a,b>, other: reactive-top<c>, callback: listen-fn<c>, ?kk-file-line: string): react-eff subscription<c>
  r.reactive.listen(other.force, callback)
pub fun delayed/on(r : rref<a>, other: reactive-top<b>, callback: listen-fn<b>, ?kk-file-line: string): react-eff subscription<b>
  r.listen(other.force, callback)
pub fun rref/listen-select(r: rref<a>, other: reactive<b>, selector: b -> c, f: listen-fn<c>, ?(==): (c, c) -> bool, ?kk-file-line: string): react-eff subscription<b>
  val last = ref(Nothing)
  fun notify(x)
    val next = selector(x)
    match !last
      Nothing -> // If this is the first time we are called
        last := Just(next) // Set the last value to the current one
        True // Call the callback with the current value
      Just(l) ->
        if l != next then // If the value has changed
          last := Just(next) // Set the last value to the current one
          True // Call the callback with the current value
        else 
          False
  r.rref/listen(other, fn(x) f(selector(x)), notify) // Add the listener to the list of listeners
pub fun family/listen-select(r: family-instance<a,b>, other: reactive-top<c>, selector: c -> d, f: listen-fn<d>, ?(==): (d, d) -> bool, ?kk-file-line: string): react-eff subscription<c>
  r.reactive.listen-select(other.force, selector, f)
pub fun delayed/listen-select(r: rref<a>, other: reactive-top<b>, selector: b -> c, f: listen-fn<c>, ?(==): (c, c) -> bool, ?kk-file-line: string): react-eff subscription<b>
  r.listen-select(other.force, selector, f)


// Listen-self is a special case of listen, where we want to listen to the current reactive's state
// We don't have to provide the reactive we want to listen to, since we are already in the context of the reactive
// And we add the cancelation to our own cancelation list
pub fun rref/listen-self(r : rref<a>, callback: listen-fn<a>, immediate: bool = False, ?kk-file-line: string): react-eff subscription<a>
  val sub = r.rref.listen(callback, fn(x) True, immediate=immediate) // Add the listener to the list of listeners
  r.rref.add-subscription(sub)
  sub
pub fun family/listen-self(r : family-instance<a,b>, callback: listen-fn<a>, immediate: bool = False, ?kk-file-line: string): react-eff subscription<a>
  r.reactive.rref/listen-self(callback, immediate=immediate)

fun listener/pause(l: listener<a>): listener<a>
  match l
    Listener(sid, callback, canceled, _, notify) -> Listener(sid, callback, canceled, True, notify)
fun listener/unpause(l: listener<a>): listener<a>
  match l
    Listener(sid, callback, canceled, _, notify) -> Listener(sid, callback, canceled, False, notify)
fun sub/cancel(l : subscription<a>)
  l.canceled.set(True)

// Some helper functions to manage subscription, stops when it finds the listener and adjusts it
alias listeners<a> = list<listener<a>>
fun listeners/pause(listeners: listeners<a>, id: int): listeners<a>
  match listeners
    Nil -> Nil // TODO: Error?
    Cons(l, ls) ->
      if l.sid == id then Cons(l.pause, ls)
      else Cons(l, pause(ls, id))
fun listeners/unpause(listeners: listeners<a>, id: int): listeners<a>
  match listeners
    Nil -> Nil // TODO: Error?
    Cons(l, ls) ->
      if l.sid == id then Cons(l.unpause, ls)
      else Cons(l, unpause(ls, id)) 

// Helper functions to manage subscriptions
// The subscriptions keep track of which watch call occurs before which subscriptions
// This way when a reactive's dependency changes
//  - we cancel the subscriptions that are no longer valid
//  - but keep the ones that occurred before the watch
abstract struct subscriptionx
  cancel: unit-cb

fun sub-cancel(sub: subscription<b>): unit-cb
  fn() 
    sub.cancel(); 
    sub.rref.rref.cancel_(sub)

fun reactor/add-subscription(r: ev<reactor<a>>, sub: subscription<b>): react-eff ()
  r.add-cancel(sub.sub-cancel)

alias subscriptions = list<(int, list<subscriptionx>)>
// Adds to the latest subscription list
fun add-sub(subs: subscriptions, sub: subscriptionx): exn subscriptions
  match subs
    Cons((xi, cs), css) -> Cons((xi, Cons(sub, cs)), css)
// Add the cancel function to the cancelation list prior to the current id
fun add-cancel-before(subs: subscriptions, id: int, sub: subscriptionx): exn subscriptions
  match subs
    Cons((ix, cs), css) | ix < id -> Cons((ix, Cons(sub, cs)), css)
    Cons(cs, css) -> Cons(cs, css.add-cancel-before(id, sub))
// Cancel and remove all cancelations that are after the current id
fun split-after(subs: subscriptions, id: int): react-eff (list<subscriptionx>, subscriptions)
  match subs
    Nil -> 
      (Nil, Nil)
    Cons((ix, _), _) | ix < id ->
      ([], subs)
    Cons((ix, cancels), rst) | ix == id -> 
      (cancels, rst)
    Cons((_, cancels), rst) ->
      val (cancels', subs') = split-after(rst, id)
      (cancels ++ cancels', subs')

fun cancel-all-after(subs: subscriptions, id: int): react-eff subscriptions
  val (cancels, subs') = subs.split-after(id)
  cancels.foreach(fn(s) s.cancel.())
  subs'

// A wrapper around `def-reactive` that creates a memoized family of reactives
// If the same argument is used, the same reactive is returned
// This is useful for creating families of reactives that are similar, but have different arguments
pub fun def-family(reactor-fn: (family-instance<a,b>) -> react-eff a, name: maybe<string> = Nothing, auto-reset = True,
                  ?b/show: (b) -> react-eff string, ?b/(==): (b, b) -> react-eff bool,
                  ?a/show: (a) -> react-eff string, ?a/(==): (a, a) -> react-eff bool, ?kk-file-line: string): (b -> react-eff reactive-top<a>)
  with unsafe-total
  // Memoized list of all reactives using the `reactor-fn`, with one reactive per unique argument
  val reactives : some<a,b> ref<global,list<(b, reactive-top<a>)>> = ref([])
  fn(arg: some<b> b)
    // Check if the reactive already exists
    val react = (!reactives).find(fn(r) r.fst == arg)
    match react
      Just(r) -> r.snd // If so return
      Nothing -> // Else create it based off of the reactor-fn template, and the reactive argument
        val r = 
          with delay
          mk-reactive(name = name.map(fn(n) n ++ arg.show), auto-reset = auto-reset, is-family = True, ?show=a/show) fn(ref)
            ref.rref/rref.add-cancel fn() 
              // trace("Removed family " ++ arg.show)
              reactives := (!reactives).filter(fn(r) !(r.fst == arg))
            reactor-fn(Instance(ref, arg))
        reactives := Cons((arg, r), (!reactives))
        r

// Defines a new reactive under a delay so it can be stored in a top-level variable
pub fun def-reactive(reactor-fn: rref<a> -> react-eff a, name: maybe<string> = Nothing, auto-reset = False,
                    ?show: (a) -> react-eff string, ?(==): (a, a) -> react-eff bool, ?kk-file-line: string): reactive-top<a>
  with delay
  mk-reactive(reactor-fn, name = name, auto-reset = auto-reset)

// Constructs a new reactive, with a name and a function `reactor-fn` to run to manage state
fun mk-reactive(reactor-fn: rref<a> -> react-eff a, name: maybe<string> = Nothing, auto-reset = False, is-family = False,
                ?show: (a) -> react-eff string, ?(==): (a, a) -> react-eff bool, ?kk-file-line: string): react-eff reactive<a>
  // The name of the reactive
  val xname = name.default(kk-file-line) 
  // The starting continuation of the reactive (after initializing the handler value)
  val init: ref<global, unit-cb> = ref(fn(){})
  // The current state of the reactive
  val current-state : some<a> ref<global, maybe<a>> = ref(Nothing) 
  // The other things listening to this reactive
  val listeners : some<a> ref<global, listeners<a>> = ref([]) 
  // What subscriptions should be canceled if a dependency changed 
  val subscriptions : ref<global, subscriptions> = ref([(-1, [])]) 
  // Whether the reactive should react to any changes
  val paused = ref(False) 
  // The next thing to resume after unpausing
  val next : ref<global, maybe<unit-cb>> = ref(Nothing) 
  // The named handler value
  val refx: some<a> ref<global, maybe<reactive<a>>> = ref(Nothing)
  // A unique counter, that only increments
  val unique = ref(0) 
  fun get-unique-id(): st<global> int
    val unique-id = !unique
    unique := !unique + 1
    unique-id
  val resetting = ref(False)
  fun do-reset() 
    if !resetting then ()
    else 
      resetting := True
      current-state := Nothing
      // trace("Subscriptions " ++ (!subscriptions).length.show)
      (!subscriptions).foreach(fn(f) f.snd.foreach(fn(f') f'.cancel.()))
      subscriptions := [(-1, [])]
      next := Nothing
      resetting := False
    // TODO: What about listeners?
  fun check-reset()
    val n-listeners = (!listeners).length 
    if n-listeners == 0 || is-family && n-listeners == 1 then // Maybe reset
      // trace((!listeners).length.show ++ " listeners for " ++ xname ++ " " ++ is-family.show)
      paused := True
      if auto-reset then 
        do-reset()
    // else
    //   trace((!listeners).length.show ++ " listeners for " ++ xname ++ " " ++ is-family.show)
  // The initialization routine
  val do-init = fn(rref)
        refx := Just(Reactive(rref)) // First make sure that the handler value can be accessed
        rref.init-yield_() // Then yield, to not eagerly initialize until someone demands the value
        val result = reactor-fn(Ref(rref)) // Then initialize using the user provided reactor function
        rref.emit_(result) // Then we emit the final result of the user provided function
        () // But we don't return anything directly
  // The reactive itself
  named handle(do-init)
    // Yield to initialize the reactive's state only when demanded
    raw ctl init-yield_() 
      init := (fn() {rcontext.resume(())})
    fun is-initialized()
      (!current-state).is-just
    // The name of the reactive
    fun name_() xname
    // The state function
    fun current_() 
      match !current-state 
        Nothing -> // If the state is not initialized
          (!init)() // Resume for the initialization
          // The state should be initialized now
          (!current-state).expect("Problem initializing " ++ xname) 
        Just(k) -> k // The state is already initialized, return its current value
    fun reset_() 
      do-reset()
    fun check-reset()
      check-reset()
    fun restart_() 
      do-reset()
      (!init)()
    // Subscription handling
    fun cancel_(s)
      listeners := (!listeners).filter(fn(l) l.sid != s.sid)
      check-reset()
    fun pause_(s)
      listeners := (!listeners).pause(s.sid)
    fun unpause_(s)
      listeners := (!listeners).unpause(s.sid)
    // Reactor management
    fun pause()
      paused := True
    fun unpause() // Unpause and resume from whichever was the first dependency that changed
      paused := False
      match !next
        Just(cb) ->
          cb()
          next := Nothing
        Nothing -> ()
    fun emit_(new-state) // Emitting a new state
      val st = !current-state
      if st.is-just && st.unjust == new-state then
        () // Don't cause unnecessary updates to dependencies if the value hasn't changed
      else
        current-state := Just(new-state) // Set the current state
        // TODO: Split this out into a scheduler?
        // TODO: We need to only call the first watcher for each reactive (in the reversed list) (unless the first one shouldn't be notified)
        // Or we need to handle the fact that listeners could be removed when we are iterating over them
        // Such as containing a mutable canceled field that we could check
        (!listeners).reverse.foreach fn(listener) // Notify all listeners
          if !(!(listener.sub.canceled)) && listener.notify.(new-state) then
            listener.callback.(new-state)
          ()
    fun listen_(f, dependent, notify) // Set a function to run whenever the current reactive's state changes.
      val uid = get-unique-id()
      // trace("registering listener for " ++ xname ++ " with id " ++ xi.show ++ " from " ++ dependent)
      val sub = Subscription(uid, Ref((!refx).unjust.rref), ref(False))
      listeners := Cons(Listener(uid, f, sub, False, notify), !(listeners)) // Add the listener to the list of listeners
      sub
    fun add-cancel(cancel)
      subscriptions := (!subscriptions).add-sub(Subscriptionx(cancel))
    raw ctl watch_(other, immediate, selector)
      // TODO: Split this out into a scheduler?
      // Watch the value of another reactive
      // Add our own continuation to the other-reactive's listeners
      fun sel(x)
        match selector
          Selector(sel, _) -> sel(x)
      val uid = get-unique-id()
      val last = ref(Nothing)
      fun notify(b)
        match selector
          Selector(select, eq) ->
            val nextv = select(b)
            match !last
              Nothing -> // If this is the first time we are called
                last := Just(nextv) // Set the last value to the current one
                True
              Just(l) ->
                if !eq(l, nextv) then // If the value has changed
                  last := Just(nextv) // Set the last value to the current one
                  True // Call the callback with the current value
                else 
                  False
      // trace("watching " ++ other-reactive.rref.name_() ++ " from " ++ xname)
      val sub = other.rref.listen_(dependent=xname, notify=notify) fn(b)
        // trace("Canceling previous listeners")
        subscriptions := (!subscriptions).cancel-all-after(uid) // Cancel
        // TODO: Just mutate a flag, and then call the accumulated cancelation functions after mutating cancelations to refer to the new cancelations list
        // trace("Adding new cancelation list")
        subscriptions := Cons((uid, []), !subscriptions)
        if !(!paused) then
          rcontext.resume(sel(b))
        else 
          next := Just(fn() rcontext.resume(sel(b)))
      // trace("Got cancelation")
      subscriptions := (!subscriptions).add-cancel-before(uid, Subscriptionx(sub.sub-cancel))
      if !(!paused) then
        if other.rref.is-initialized() then
          rcontext.resume(sel(other.current()))
          ()
        elif immediate then
          other.current()
          ()
        else ()
      else ()
  // The reactive should be initialized (since we don't pause initialization until after setting `refx`)
  // We can safely call `unjust` on it here
  (!refx).unjust


// The following functions are just wrappers around the reactor's methods
pub fun rref/restart(r: rref<a>): pure ()
  r.rref.restart_()
pub fun family/restart(r: family-instance<a,b>): pure ()
  r.reactive.restart()
pub fun reactive/restart(r: reactive<a>): pure ()
  r.rref.restart_()
pub fun delayed/restart(r: reactive-top<a>): react-eff ()
  r.force.restart()
pub fun rref/reset(r: rref<a>): pure ()
  r.rref.reset_()
pub fun family/reset(r: family-instance<a,b>): pure ()
  r.reactive.reset()
pub fun reactive/reset(r: reactive<a>): pure ()
  r.rref.reset_()
pub fun delayed/reset(r: reactive-top<a>): react-eff ()
  r.force.reset()
pub fun rref/check-reset(r: rref<a>): pure ()
  r.rref.check-reset()
pub fun family/check-reset(r: family-instance<a,b>): pure ()
  r.reactive.check-reset()
pub fun reactive/check-reset(r: reactive<a>): pure ()
  r.rref.check-reset()
pub fun delayed/check-reset(r: reactive-top<a>): react-eff ()
  r.force.check-reset()
pub fun rref/pause(r: rref<a>): pure ()
  r.rref.pause()
pub fun family/pause(r: family-instance<a,b>): pure ()
  r.reactive.pause()
pub fun reactive/pause(r: reactive<a>): pure ()
  r.rref.pause()
pub fun delayed/pause(r: reactive-top<a>): react-eff ()
  r.force.pause()
pub fun rref/unpause(r: rref<a>): pure ()
  r.rref.unpause()
pub fun family/unpause(r: family-instance<a,b>): pure ()
  r.reactive.unpause()
pub fun reactive/unpause(r: reactive<a>): pure ()
  r.rref.unpause()
pub fun delayed/unpause(r: reactive-top<a>): react-eff ()
  r.force.unpause()
pub fun rref/current(r: rref<a>): react-eff a
  val sub = r.rref.listen_(fn(_) (), "", fn(_) False)
  val x = r.rref.current_()
  sub.cancel.()
  sub.rref.rref.cancel_(sub)
  x
pub fun family/current(r: family-instance<a,b>): react-eff a
  r.reactive.current()
pub fun reactive/current(r: reactive<a>): react-eff a
  val sub = r.rref.listen_(fn(_) (), "", fn(_) False)
  val x = r.rref.current_()
  sub.cancel.()
  sub.rref.rref.cancel_(sub)
  x
pub fun delayed/current(r: reactive-top<a>): react-eff a
  r.force.current()
pub fun rref/name(r: rref<a>): pure string
  r.rref.name_()
pub fun family/name(r: family-instance<a,b>): pure string
  r.reactive.name()
pub fun reactive/name(r: reactive<a>): pure string
  r.rref.name_()
pub fun delayed/name(r: reactive-top<a>): react-eff string
  r.force.name()
pub fun rref/emit(r: rref<a>, a: a): pure ()
  r.rref.emit_(a)
pub fun family/emit(r: family-instance<a,b>, a: a): pure ()
  r.reactive.emit(a)
pub fun rref/mutate(r: reactive<a>, a: a): pure ()
  r.rref.emit_(a)
pub fun delayed/mutate(r: reactive-top<a>, a: a): react-eff ()
  r.force.rref.emit_(a)
pub fun rref/call(r: reactive<a>, a: a): pure ()
  r.rref.emit_(a)
pub fun delayed/call(r: reactive-top<a>, a: a): react-eff ()
  r.force.rref.emit_(a)


/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module reactives


alias unit-cb = () -> <pure, st<global>> ()

// A reactive reference, let's us interact with other reactives
named effect reactor<a>
  // This is internal
  ctl init-yield_(): () 
  fun is-initialized(): bool
  // We can emit a value from our reactive
  fun emit_(a: a): () 
  // We can watch other reactives
  ctl watch_<b>(p: reactive<b>, immediate: bool): b 
  // We can add listeners to the reactive 
  fun listen_(f: (a) -> <pure,st<global>> (), dependent: string): subscription
  fun cancel_(s: subscription): ()
  fun pause_(s: subscription): ()
  fun unpause_(s: subscription): ()
  // Restart
  fun restart_(): () 
  fun reset_(): () 
  // Get the current state
  fun current_(): a
  // Add a cancelation
  fun add-cancelation(cleanup: unit-cb): ()
  // An identifier for the reactive
  fun name_() : string

// A reactive just wraps the reactive ref
abstract div type reactive<a>
  Reactive(rref: ev<reactor<a>>)

abstract div type rref<a>
  Ref(rref: ev<reactor<a>>)

abstract type listener<a>
  Listener(sid: int, callback: (a) -> <pure,st<global>> (), paused: bool = False)

abstract struct subscription
  sid: int

// Watching a reactive is just a matter of adding our own continuation to the other-reactive's listeners
fun reactor/watch(r: ev<reactor<a>>, p: reactive<b>, immediate: bool = False): pure b
  r.watch_(p, immediate)

fun reactor/listen(r: ev<reactor<a>>, f: (a) -> <pure,st<global>> (), immediate: bool = False, ?kk-file-line: string): <pure,st<global>> subscription
  val sub = r.listen_(f, ?kk-file-line) // Add the listener to the list of listeners
  if r.is-initialized() && immediate then 
    f(r.current_())
    sub
  elif immediate then // If we want to trigger the listener immediately
    r.current_() // Demand it's current value to make sure we get the latest
    sub
  else sub

pub fun rref/restart(r: rref<a>): pure ()
  r.rref.restart_()
pub fun reactive/restart(r: reactive<a>): pure ()
  r.rref.restart_()
pub fun rref/reset(r: rref<a>): pure ()
  r.rref.reset_()
pub fun reactive/reset(r: reactive<a>): pure ()
  r.rref.reset_()
pub fun rref/current(r: rref<a>): pure a
  r.rref.current_()
pub fun reactive/current(r: reactive<a>): pure a
  r.rref.current_()
pub fun rref/name(r: rref<a>): pure string
  r.rref.name_()
pub fun reactive/name(r: reactive<a>): pure string
  r.rref.name_()

pub fun rref/watch(r: rref<a>, p: reactive<b>, immediate: bool = False): pure b
  r.rref.watch(p, immediate)

pub fun rref/emit(r: rref<a>, a: a): pure ()
  r.rref.emit_(a)

pub fun rref/listen(r : rref<a>, p: reactive<b>, f: (b) -> <pure,st<global>> (), immediate: bool = False, ?kk-file-line: string): <pure,st<global>> subscription
  val sub = p.rref.listen(f, immediate=immediate) // Add the listener to the list of listeners
  r.rref.add-cancelation(fn() p.rref.cancel_(sub))
  sub
pub fun rref/listen-self(r : rref<a>, f: (a) -> <pure,st<global>> (), immediate: bool = False, ?kk-file-line: string): <pure,st<global>> subscription
  val sub = r.rref.listen(f, immediate=immediate) // Add the listener to the list of listeners
  r.rref.add-cancelation(fn() r.rref.cancel_(sub))
  sub

fun pause(listeners: list<listener<a>>, id: int): list<listener<a>>
  match listeners
    Nil -> Nil // TODO: Error?
    Cons(l, ls) ->
      if l.sid == id then Cons(l(paused = True), ls)
      else Cons(l, pause(ls, id))

fun unpause(listeners: list<listener<a>>, id: int): list<listener<a>>
  match listeners
    Nil -> Nil // TODO: Error?
    Cons(l, ls) ->
      if l.sid == id then Cons(l(paused = False), ls)
      else Cons(l, pause(ls, id))
    
fun add-dispose(cancelations, cancel)
  match cancelations
    Cons((xi, cs), css) -> Cons((xi, Cons(cancel, cs)), css)

fun dispose-before(cancelations: list<(int, list<unit-cb>)>, id: int, cancel: unit-cb)
  match cancelations
    Cons((ix, cs), css) | ix < id -> Cons((ix, Cons(cancel, cs)), css)
    Cons(cs, css) -> Cons(cs, css.dispose-before(id, cancel))

pub fun mk-reactive(reactor-fn: rref<a> -> <pure,st<global>> a, name: maybe<string> = Nothing, ?show: (a) -> <pure,st<global>> string, ?kk-file-line: string): <pure,st<global>> reactive<a>
  // The current state of the reactive
  val current-state : some<a> ref<global, maybe<a>> = ref(Nothing)
  // The yielding context of the reactive, used delay the initialization
  val init: ref<global, () -> <pure,st<global>> ()> = ref(fn(){})
  // The value for this handler
  val refx: some<a> ref<global, maybe<reactive<a>>> = ref(Nothing)
  val xname = name.default(kk-file-line)
  // The initialization routine
  val do-init = fn(rref)
        refx := Just(Reactive(rref))
        rref.init-yield_() // First yield, to not eagerly initialize
        val result = reactor-fn(Ref(rref)) // Then when demanded the first time we initialize, using the user provided reactor function
        rref.emit_(result) // Then we emit the final result of the user provided function
        () // But we don't return anything directly
  
  val listeners : some<a> ref<global, list<listener<a>>> = ref([])
  val cancelations : ref<global, list<(int, list<unit-cb>)>> = ref([(-1, [])])
  fun state() // The state function
    match !current-state // If the state is not initialized
      Nothing -> 
        (!init)() // Resume for the initialization
        match !current-state // If the state is not initialized
          Nothing -> 
            throw("Problem initializing " ++ xname)
          Just(x) -> 
            x // If the state is initialized, we return the value
      Just(k) -> k // The state is already initialized, return it's current value
  val i = ref(0)
  fun get-i(): st<global> int
    val xi = !i
    i := !i + 1
    xi
  fun cancel-after(cancelations': list<(int, list<unit-cb>)>, id: int)
    match cancelations'
      Nil -> 
        cancelations := Nil
      Cons((ix, _), _) | ix < id ->
        cancelations := cancelations'
      Cons((ix, cancels), rst) | ix == id -> 
        cancels.foreach(fn(c) c())
        cancelations := rst
      Cons((_, cancels), rst) ->
        cancels.foreach(fn(c) c())
        cancel-after(rst, id)
  // The reactive itself
  named handle(do-init)
    fun name_() xname
    fun add-cancelation(cancel) 
      cancelations := (!cancelations).add-dispose(cancel)
    fun current_() state()
    raw ctl init-yield_() // Yield to initialize the reactive only when demanded
      init := (fn() {rcontext.resume(())})
    fun reset_()
      current-state := Nothing
      (!cancelations).foreach(fn(f) f.snd.foreach(fn(f') f'()))
      cancelations := [(-1, [])]
    fun is-initialized()
      (!current-state).is-just
    fun restart_()
      current-state := Nothing
      // trace("Cancelations " ++ (!cancelations).length.show)
      // TODO: Split this out into a scheduler
      (!cancelations).foreach(fn(f) f.snd.foreach(fn(f') f'()))
      cancelations := [(-1, [])]
      (!init)()
    fun emit_(new-value) // Emitting
      current-state := Just(new-value) // Set the current state
      // TODO: Split this out into a scheduler
      (!listeners).foreach fn(listener) // Notify all listeners
        listener.callback.(new-value)
    fun listen_(f, dependent) // Set a function to run whenever the current reactive's state changes.
      val xi = get-i()
      // trace("registering listener for " ++ xname ++ " with id " ++ xi.show ++ " from " ++ dependent)
      listeners := Cons(Listener(xi, f), !(listeners)) // Add the listener to the list of listeners
      Subscription(xi)
    fun cancel_(s)
      listeners := (!listeners).filter(fn(l) l.sid != s.sid)
    fun pause_(s)
      listeners := (!listeners).pause(s.sid)
    fun unpause_(s)
      listeners := (!listeners).unpause(s.sid)
    raw ctl watch_(other-reactive, trigger-immediately)
      // TODO: Split this out into a scheduler
      // Watch the value of another reactive
      // Add our own continuation to the other-reactive's listeners
      val id = get-i()
      // trace("watching " ++ other-reactive.rref.name_() ++ " from " ++ xname)
      val sub = other-reactive.rref.listen_(dependent=xname) fn(b)
        // trace("Canceling previous listeners")
        (!cancelations).cancel-after(id) // Cancel
        // trace("Adding new cancelation list")
        cancelations := Cons((id, []), !cancelations)
        rcontext.resume(b)
      // trace("Got cancelation")
      cancelations := (!cancelations).dispose-before(id, fn() other-reactive.rref.cancel_(sub))
      if other-reactive.rref.is-initialized() then
        rcontext.resume(other-reactive.current())
        ()
      elif trigger-immediately then
        other-reactive.current()
        ()
      else ()
  (!refx).unjust

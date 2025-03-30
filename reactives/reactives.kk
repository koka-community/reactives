/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module reactives

// A reactive reference, let's us interact with other reactives
named effect rref<a>
  // This is internal
  ctl init-yield_(): () 
  // We can emit a value from our reactive
  fun emit_(a: a): () 
  // We can watch other reactives
  ctl watch_<b>(p: reactive<b>, immediate: bool): b 
  // We can add listeners to the reactive 
  fun listen_(f: (a) -> <pure,st<global>> (), dependent: string): (() -> <pure,st<global>> ()) 
  // Restart
  fun restart_(): () 
  // Get the current state
  fun current_(): a
  // Add a cancelation
  fun add-cancelation(cleanup: () -> <pure,st<global>> ()): ()
  // An identifier for the reactive
  fun name_() : string

// Watching a reactive is just a matter of adding our own continuation to the other-reactive's listeners
fun rref/watch(r: ev<rref<a>>, p: reactive<b>, immediate: bool = False): pure b
  r.watch_(p, immediate)

fun rref/listen(r: ev<rref<a>>, f: (a) -> <pure,st<global>> (), immediate: bool = False, ?kk-file-line: string): pure (() -> <pure,st<global>> ()) 
  val cancel = r.listen_(f, ?kk-file-line) // Add the listener to the list of listeners
  if immediate then // If we want to trigger the listener immediately
    r.current_() // Demand it's current value to make sure we get the latest
    cancel
  else cancel

// A reactive just wraps the reactive ref
pub div type reactive<a>
  Reactive(rref: ev<rref<a>>, self: bool)

pub fun reactive/watch(r: reactive<a>, p: reactive<b>, immediate: bool = False): pure b
  r.rref.watch(p, immediate)

pub fun reactive/restart(r: reactive<a>): pure ()
  r.rref.restart_()

pub fun reactive/emit(r: reactive<a>, a: a): pure ()
  r.rref.emit_(a)

pub fun reactive/current(r: reactive<a>): pure a
  r.rref.current_()

pub fun reactive/name(r: reactive<a>): pure string
  r.rref.name_()

pub fun reactive/listen(r : reactive<a>, f: (a) -> <pure,st<global>> (), immediate: bool = False, ?kk-file-line: string): pure (() -> <pure,st<global>> ()) 
  val cancel = r.rref.listen(f, immediate=immediate) // Add the listener to the list of listeners
  if r.self then 
    r.rref.add-cancelation(cancel)
    cancel
  else cancel

pub fun mk-reactive(reactor-fn: reactive<a> -> <pure,st<global>> a, name: maybe<string> = Nothing, ?show: (a) -> <pure,st<global>> string, ?kk-file-line: string): <pure,st<global>> reactive<a>
  // The current state of the reactive
  val current-state : some<a> ref<global, maybe<a>> = ref(Nothing)
  // The yielding context of the reactive, used delay the initialization
  val init: ref<global, () -> <pure,st<global>> ()> = ref(fn(){})
  // The value for this handler
  val refx: some<a> ref<global, maybe<reactive<a>>> = ref(Nothing)
  val xname = name.default(kk-file-line)
  // The initialization routine
  val do-init = fn(rref)
        refx := Just(Reactive(rref, False))
        rref.init-yield_() // First yield, to not eagerly initialize
        val result = reactor-fn(Reactive(rref, True)) // Then when demanded the first time we initialize, using the user provided reactor function
        rref.emit_(result) // Then we emit the final result of the user provided function
        () // But we don't return anything directly
  
  val listeners : some<a> ref<global, list<(int,(a) -> <pure,st<global>> ())>> = ref([])
  val cancelations : ref<global, list<() -> <pure,st<global>> ()>> = ref([])
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
  // The reactive itself
  named handle(do-init)
    fun name_() xname
    fun emit_(new-value) // Emitting
      current-state := Just(new-value) // Set the current state
      (!listeners).foreach fn(listener) // Notify all listeners
        listener.snd.(new-value)
    fun listen_(f, dependent) // Set a function to run whenever the current reactive's state changes.
      val xi = !i
      // trace("registering listener for " ++ xname ++ " with id " ++ xi.show ++ " from " ++ dependent)
      listeners.set(Cons((xi, f), !(listeners))) // Add the listener to the list of listeners
      val cancel = fn()
        // trace("canceling listener for " ++ xname ++ " with id " ++ xi.show ++ " from " ++ dependent)
        listeners.set((!listeners).filter(fn(l) l.fst != xi))
      i := xi + 1
      cancel
    fun add-cancelation(cancel)
      cancelations.set(Cons(cancel, !cancelations))
    raw ctl init-yield_() // Yield to initialize the reactive only when demanded
      init := (fn() {rcontext.resume(())})
    raw ctl watch_(other-reactive, trigger-immediately)
      // Watch the value of another reactive
      // Add our own continuation to the other-reactive's listeners
      // trace("watching " ++ other-reactive.rref.name_() ++ " from " ++ xname)
      val cancel = other-reactive.listen(fn(b) rcontext.resume(b))
      // trace("Got cancelation")
      cancelations.set(Cons(cancel, !cancelations))
      if trigger-immediately then 
        other-reactive.current()
        ()
      else ()
    fun restart_()
      current-state := Nothing
      // trace("Cancelations " ++ (!cancelations).length.show)
      (!cancelations).foreach(fn(f) f())
      (!init)()
    fun current_()
      state()
  (!refx).unjust

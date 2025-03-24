/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module reactives

// A reactive reference, let's us interact with other reactives
pub named effect rref<a>
  fun emit(a: a): () // We can emit a value from our reactive
  ctl watch_<b>(p: reactive<b>, immediate: bool): b // We can watch other reactives
  fun listen-self(f: (a) -> <pure,st<global>> ()): () // We can listen to our own reactive
  ctl init-yield_(): () // We can yield our reactive 

// Watching a reactive is just a matter of adding our own continuation to the other-reactive's listeners
pub fun watch(r: ev<rref<a>>, p: reactive<b>, immediate: bool = True): <pure,st<global>> b
  r.watch_(p, immediate)

// A reactive is really just a current state accessor (to initialize demand), and a list of listeners
div type reactive<a>
  Reactive(
    listeners: ref<global, list<(a) -> <pure,st<global>> ()>>,
    current: () -> <pure,st<global>> a
  )

pub fun listen(r : reactive<a>, f: (a) -> <pure,st<global>> (), immediate: bool = True): <pure,st<global>> ()
  r.listeners.set(Cons(f, !(r.listeners))) // Add the listener to the list of listeners
  if immediate then // If we want to trigger the listener immediately
    (r.current)() // Demand it's current value to make sure we get the latest
    ()

pub fun mk-reactive(reactor-fn: ev<rref<a>> -> <pure,st<global>> a, name: maybe<string> = Nothing, ?show: (a) -> <pure,st<global>> string, ?kk-file-line: string): <pure,st<global>> reactive<a>
  // The current state of the reactive
  val current-state : some<a> ref<global, maybe<a>> = ref(Nothing)
  // The yielding context of the reactive, used delay the initialization
  val continuex: ref<global, () -> <pure,st<global>> ()> = ref(fn(){})
  // The initialization routine
  val do-init = fn(rref)
         rref.init-yield_() // First yield, to not eagerly initialize
         val result = reactor-fn(rref) // Then when demanded the first time we initialize, using the user provided reactor function
         rref.emit(result) // Then we emit the final result of the user provided function
         () // But we don't return anything directly
  
  // The reactive itself
  val reactive = Reactive(ref([]), // No listeners yet
    fn(){ // The state function
    match !current-state // If the state is not initialized
      Nothing -> 
        (!continuex)() // Resume for the initialization
        match !current-state // If the state is not initialized
          Nothing -> throw("Problem initializing the reactive on line " ++ kk-file-line)
          Just(x) -> x // If the state is initialized, we return the value
      Just(k) -> k // The state is already initialized, return it's current value
    })
  
  named handle(do-init)
    fun emit(new-value) // Emitting
      current-state := Just(new-value) // Set the current state
      (!reactive.listeners).foreach fn(listener) // Notify all listeners
        listener(new-value)
    fun listen-self(f) // Set a function to run whenever the current reactive's state changes.
      reactive.listen(f, immediate = False)
    raw ctl init-yield_() // Yield to initialize the reactive only when demanded
      continuex := (fn() {rcontext.resume(())})
    raw ctl watch_(other-reactive, trigger-immediately)
      // Watch the value of another reactive
      // Add our own continuation to the other-reactive's listeners
      other-reactive.listen(fn(b) rcontext.resume(b), immediate = trigger-immediately)
  // Return the reactive
  reactive

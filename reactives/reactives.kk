/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module reactives

pub named effect rref<a>
  fun emit(a: a): ()
  ctl watch_<b>(p: reactive<b>, immediate: bool): b
  fun listen-self(f: (a) -> <pure,st<global>> ()): ()
  ctl yield(): ()

pub fun watch(r: ev<rref<a>>, p: reactive<b>, immediate: bool = True): <pure,st<global>> b
  r.watch_(p, immediate)

pub div type reactive<a>
  Reactive(
    listeners: ref<global, list<(a) -> <pure,st<global>> ()>>,
    current: () -> <pure,st<global>> a
  )

pub fun mk-reactive(reactor-fn: ev<rref<a>> -> <pure,st<global>> a, name: maybe<string> = Nothing, ?show: (a) -> <pure,st<global>> string, ?kk-file-line: string): <pure,st<global>> reactive<a>
  // The state of the 
  val current-state : some<a> ref<global, maybe<a>> = ref(Nothing)
  val continuex: ref<global, () -> <pure,st<global>> ()> = ref(fn(){})
  val do-init = fn(rref)
         rref.yield()
         val result = reactor-fn(rref)
         rref.emit(result)
         ()
  val reactive = Reactive(ref([]), fn(){ 
    match !current-state
      Nothing -> 
        (!continuex)()
        match !current-state
          Nothing -> throw("Not initialize")
          Just(x) -> x
      Just(k) ->
        k
    })
  named handle(do-init)
    fun emit(new-value)
      current-state := Just(new-value)
      (!reactive.listeners).foreach fn(listener)
        listener(new-value)
    fun listen-self(f)
      reactive.listeners.set(Cons(f, !(reactive.listeners)))
    raw ctl yield()
      continuex := (fn() {rcontext.resume(())})
    raw ctl watch_(other-reactive, trigger-immediately)
      other-reactive.listeners.set(Cons(fn(b) {rcontext.resume(b)}, !(other-reactive.listeners)))
      if trigger-immediately then
        (other-reactive.current)()
        ()
     
  reactive

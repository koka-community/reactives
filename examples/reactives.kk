/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import reactives/reactives

// A reactive can be a top-level variable!
val r1 : reactive-top<int> =
   // You define it like this
   with r <- def-reactive(name = Just("r1"))
   println("Init r1")
   // You can listen to your own state changes
   r.rref/listen-self fn(x: int) 
      trace("R1: " ++ x.show)
   
   println("emit 0 from r1")
   // You can emit new states
   r.emit(0)

   println("emit 1 from r1")
   r.emit(1)

   println("emit 2 from r1")
   // The return value is the last state that is emitted (and usually the starting state as well)
   2

// You can create other reactives that depend on the first
val r2 : reactive-top<int> = 
   with r <- def-reactive(name = Just("r2"))
   r.rref/listen-self fn(x: int) 
      println("R2: " ++ x.show)
   println("Init r2")

   // Using `select` you can just be notified when a derived value from `r1` changes
   // Only the rest of the body will be rerun when this dependency changes
   // Earlier computations that are not affected will not be recomputed (so you won't recompute expensive stuff)
   val b = r.select(r1, fn(x) x == 0)

   println("b " ++ b.show)

   // Emits a value from this reactive
   println("emit 1 from r2")
   r.emit(1)
   // Starts `watch`ing the state from `r1` (without filtering like `select`)
   // The rest of this function will change every time `r1` changes
   //  However the code between `b` and here will only change when `r1`'s state changes to or from 0
   val x = r.watch(r1)

   // Current get's the current value of this reactive. Do not call it unless it is initialized!
   r.current() + x

// Often reactives will be very simple, with some initial state.
// The following two reactives are set up to be "mutations", or reactives that start a chain of computation
val addX : reactive-top<int> = 
   with r <- def-reactive(name = Just("addX"))
   0
val subX : reactive-top<int> = 
   with r <- def-reactive(name = Just("subX"))
   0

// This reactive will depend on the mutations
val r3 : reactive-top<int> = 
   with r <- def-reactive(name = Just("r3"))
   r.rref/listen-self fn(x: int) 
      println("R3: " ++ x.show)
   println("Init r3")

   // When addX is changed
   r.on(addX) fn(x) // Add the current value of addX to our value
      r.emit(r.current() + x)
   r.on(subX) fn(x) // Subtract the current value of subX from our value
      r.emit(r.current() - x)
   
   // Emits a value from this reactive
   println("emit 2 from r3")
   r.emit(2)
   // Starts watching r2
   val x = r.watch(r2)

   r.current() * x

fun main()
   // Trigger the initial computation
   r3.current()
   // Restart r3 from the beginning - should finish faster since r2 and r1 will not be changing
   println("\nRestart r3:")
   r3.restart()
   // Explicitly mutate r3's state from the outside
   println("\nMutate r3:")
   r3.mutate(100)
   println("\nPause r3:")
   r3.pause() // Pause r3's computation, so it doesn't react
   // Restart r2 from the beginning - should finish faster since r1 will not be changing
   println("\nRestart r2:")
   r2.restart()
   // Unpause r3 to let it catch up with any updates to dependencies
   println("\nUnpause r3:")
   r3.unpause()
   // Call our mutations (i.e. set their state)
   println("\nCall mutations r3:")
   addX.call(10)
   subX.call(100)

// A reactive family, the reactive has a `arg` parameter to tell you what the reactive's argument is
val f1 : reactive-family<int,int> = 
   with n <- def-family(name = Just("f1"), ?a/show=int/show, ?b/show=int/show, ?a/(==) = int/(==), ?b/(==) = int/(==))
   val r : family-instance<int,int> = n
   r.family/listen-self fn(x: int)
      println("Family " ++ r.arg.show ++ " " ++ x.show)
   r.emit(0)
   r.arg + 2

fun example-family()
   f1(0).current()

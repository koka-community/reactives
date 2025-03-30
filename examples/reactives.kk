/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import reactives/reactives

val f1 : reactive-family<int,int> = 
   with r <- def-family(name = Just("f1"))
   r.listen-self fn(x)
      trace("Family " ++ r.arg.show ++ " " ++ x.show)
   r.emit(0)
   r.arg + 2

val r1 : reactive-top<int> =
   with r <- def-reactive(name = Just("r1"))
   r.listen-self fn(x) 
      trace("R1: " ++ x.show)
   
   trace("Hi1")
   r.emit(0)

   trace("Hi1-2")
   r.emit(1)

   trace("Hi1-3")
   2

val r2 : reactive-top<int> = 
   with r <- def-reactive(name = Just("r2"))
   r.listen-self fn(x) 
      trace("R2: " ++ x.show)
   
   val b = r.select(r1, fn(x) x == 0)
   trace("Hi2 " ++ b.show)
   // Emits a value from this reactive
   r.emit(1)
   // Starts watching r1, and triggers its initialization if not already listened to.
   val x = r.watch(r1)

   r.current() + x

val addX : reactive-top<int> = 
   with r <- def-reactive(name = Just("addX"))
   0

val subX : reactive-top<int> = 
   with r <- def-reactive(name = Just("subX"))
   0

val r3 : reactive-top<int> = 
   with r <- def-reactive(name = Just("r3"))
   r.listen-self fn(x) 
      trace("R3: " ++ x.show)
   r.on(addX) fn(x) 
      r.emit(r.current() + x)
   r.on(subX) fn(x)
      r.emit(r.current() - x)
   
   trace("Hi3")
   // Emits a value from this reactive
   r.emit(2)
   // Starts watching r2, and triggers it's initialization if not already listened to.
   val x = r.watch(r2)

   r.current() * x

fun main()
   // r3.listen fn(x)
   //    trace("Final: " ++ x.show)
   r3.current()
   trace("Restart r3")
   r3.restart()
   trace("Restart r2")
   r3.mutate(100)
   r3.pause()
   r2.restart()
   r3.unpause()
   addX.call(10)
   subX.call(100)
   f1(0).current()

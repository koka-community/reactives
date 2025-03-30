/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import reactives/reactives

fun main()
   val r1 = 
         with r : reactive<int> <- mk-reactive(name = Just("r1"))
         r.listen fn(x) 
            trace("R1: " ++ x.show)
         
         r.emit(0)

         r.emit(1)

         2
   val r2 = 
         with r : reactive<int> <- mk-reactive(name = Just("r2"))
         r.listen fn(x) 
            trace("R2: " ++ x.show)
         
         trace("Hi")
         // Emits a value from this reactive
         r.emit(100)
         // Starts watching r1, and triggers it's initialization if not already listened to.
         val x = r.watch(r1, True)
         x + 1

   val r3 = 
         with r : reactive<int> <- mk-reactive(name = Just("r3"))
         r.listen fn(x) 
            trace("R3: " ++ x.show)
         
         trace("Hi2")
         // Emits a value from this reactive
         r.emit(200)
         // Starts watching r2, and triggers it's initialization if not already listened to.
         val x = r.watch(r2, True)
         if x == 3 then
            r2.emit(20)
            trace("Reset r3")
            r.restart()// Order matters?
         //    r2.restart()
         x + 2

   // r3.listen fn(x)
   //    trace("Final: " ++ x.show)
   r3.current()
/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import reactives/reactives

fun main()
   val r1 = 
         with r : rref<int> <- mk-reactive(name = Just("r1"))
         r.listen-self fn(x) 
            trace("R1: " ++ x.show)
         
         trace("Hi1")
         r.emit(0)

         trace("Hi1-2")
         r.emit(1)

         trace("Hi1-3")
         2
   val r2 = 
         with r : rref<int> <- mk-reactive(name = Just("r2"))
         r.listen-self fn(x) 
            trace("R2: " ++ x.show)
         
         trace("Hi2")
         // Emits a value from this reactive
         r.emit(1)
         // Starts watching r1, and triggers it's initialization if not already listened to.
         val x = r.watch(r1, True)

         r.current() + x

   val r3 = 
         with r : rref<int> <- mk-reactive(name = Just("r3"))
         r.listen-self fn(x) 
            trace("R3: " ++ x.show)
         
         trace("Hi3")
         // Emits a value from this reactive
         r.emit(2)
         // Starts watching r2, and triggers it's initialization if not already listened to.
         val x = r.watch(r2, True)
            
         r.current() * x

   // r3.listen fn(x)
   //    trace("Final: " ++ x.show)
   r3.current()
   trace("Restart r3")
   r3.restart()
   trace("Restart r2")
   r2.restart()
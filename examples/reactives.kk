/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import reactives/reactives

fun main()
   val r1 = 
         with r : ev<rref<int>> <- mk-reactive
         r.listen-self fn(x) 
            trace("R1: " ++ x.show)
         
         r.emit(0)

         r.emit(1)

         2
   val r2 = 
         with r : ev<rref<int>> <- mk-reactive
         r.listen-self fn(x) 
            trace("R2: " ++ x.show)
         
         trace("Hi")
         // Emits a value from this reactive
         r.emit(100)
         // Starts watching r1, and triggers it's initialization if not already listened to.
         val x = r.watch(r1, True)
         x + 1
   
   r2.listen fn(x)
      trace("Final: " ++ x.show)
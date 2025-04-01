# Reactive State Management

A reactive state management library (not a UI library, but could be used as a foundation for one).

Features:
 - Fine grained dependency tracking and incremental computation
 - Automatic subscription management
 - Support for families of reactive state that behave the same other than an initial argument

Inspired by `riverpod` from the `dart-lang` ecosystem.

See the sample in `examples/reactives.kk` for some better intuition

## How it works 

A reactor is a fine-grained piece of state, with dependency tracking and incremental computation.
A reactor notifies dependencies of changes in its state.

A reactor holds:
 - current state of a reactive element
 - listeners to call when the state changes 
 - its own continuation 
 - cancelations to run when previous dependencies change
 - a name for debugging

A reactor can: 
 - emit a value 
 - watch other reactives
 - add general listeners with managed subscriptions
 - add cancelations to run when the continuation needs to be rerun
 - pause and unpause the reactor
 - restart or reset the reactor (restart will also cause it to get the initial state, reset acts like no one cares about it anymore)
 - get the current state

Internally a reactor is a named handler, however, it is not exposed outside the defining module.

Instead there are wrappers that expose the intended interface and additionally automatically manage subscriptions etc.
- `rref<a>`: a reactor reference (self-reference), let's you manage the state of the reactor, and add subscriptions (which are automatically tracked)
- `reactive<a>`: a reference (outside the reactor) to another reactor
- `reactive-top<a>`: a reference to a top level variable (`delayed<react-eff,reactive<a>>` due to the fact that top level variables cannot have effects)
- `reactive-family<a,b>`: a family of reactives, that manage state similarly, but have different arguments (corresponds to `reactive-top<a>` with argument of type `b`)
- `family-instance<a,b>`: a family instance, that holds the reactive and the argument (similar to `rref<a>`)

## TODO:
- Better lifetime management (add hooks for user to react to more lifecycle changes)
- Overrides - via implicits?
- UI library built on this?
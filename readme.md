# Timeouts

A `Clock` that `run`s code `after` a specified duration, or `every` duration.

```nim
clock.run after(seconds=1):
  echo "Hello world"

var c = 0
clock.run every(seconds=1):
  echo $c
  inc c
```
## Install

Download this repository, unzip it, navigate to the folder and run `nimble install`

## Example

Note that this module uses the same constructor arguments you'd use for [`initDuration`](https://nim-lang.org/docs/times.html#initDuration%2Cint64%2Cint64%2Cint64%2Cint64%2Cint64%2Cint64%2Cint64%2Cint64) for a lot of procedures.

The easiest way to schedule callbacks is by taking advantage of the `Clock.run` macro. You can create and schedule a `TimeoutProc` that fires once `after` a duration, or create and schedule a `IntervalProc` that fires `every` duration. These can also be nested.

```nim
import timeouts/timeouts

# Create new clock
var clock = newClock()

# Run the following block of code `every` 10 seconds
# use the same constructor arguments you would use
# for `initDuration`.
clock.run every(seconds=10):
  echo "hello"

  # Run the following block of code after 50 milliseconds
  # Since this is nested it will fire after the parent
  # callback fires. Since we use an `after` object it will 
  # only fire once after the given duration.
  clock.run after(milliseconds=50):
    echo "world"

while true:
  # Process callbacks
  clock.tick()
  # Sleep for a fixed duration
  clock.fsleep(milliseconds=50)
```

You can also construct `TimeoutProc`s and `IntervalProc`s using some shorthand constructors so you can add them to the `Clock` with more
control.

```nim
import timeouts/timeouts

var clock = newClock()

proc test1() =
  echo "hello world"

var someTimeoutProc = test1.timeout(seconds=3)
var someIntervalProc = test1.interval(seconds=6)

clock.add(someTimeoutProc)
clock.add(someIntervalProc)

while true:
  clock.tick()
  clock.fsleep(milliseconds=50)

```

`clock.run every(seconds=10)` creates an `IntervalProc` that will fire the code contained inside of the block every 10 seconds.

`clock.run after(milliseconds=50)` creates a `TimeoutProc` that will fire the code contained inside of the block once after 50 milliseconds.

`clock.tick()` processes the callback functions that are handled on the back-end.  This proc must be called or none of the callbacks will execute.

`clock.fsleep(milliseconds=50)` will sleep for a fixed time of 50 milliseconds. In this example, if the time between `clock.tick()` and `clock.fsleep` exceeds 50 milliseconds the sleep function will not sleep at all.

`clock.sleep` is also available for ease of use. You can use it with the same arguments you would give to `initDuration` and it will sleep for that duration in milliseconds.  `clock.sleep(seconds=1, milliseconds=500)`

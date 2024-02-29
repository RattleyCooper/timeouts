# Timeouts

Run code after a specified duration, or on an interval.

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

The easiest way to do this is by taking advantage of the `Clock.run` macro.

```nim
import timeouts/timeouts

# Create new clock
var clock = newClock()

# Run the following block of code every 10 seconds
clock.run every(seconds=10):
  echo "hello"

  # Run the following block of code after 50 milliseconds
  # Since this is nested it will fire after the parent
  # callback fires.
  clock.run after(milliseconds=50):
    echo "world"

while true:
  # Process callbacks
  clock.tick()
  # Sleep for a fixed duration
  clock.fsleep(milliseconds=50)
```

`clock.run every(seconds=10)` creates an `IntervalProc` that will fire the code contained inside of the block every 10 seconds.

`clock.run after(milliseconds=50)` creates a `TimeoutProc` that will fire the code contained inside of the block once after 50 milliseconds.

`clock.tick()` processes the callback functions that are handled on the back-end.

`clock.fsleep(milliseconds=50)` will sleep for a fixed time of 50 milliseconds. In this example, if the time between `clock.tick()` and `clock.fsleep` exceeds 50 milliseconds the sleep function will not sleep at all.

`clock.sleep` is also available for ease of use. You can use it with the same arguments you would give to `initDuration` and it will sleep for that duration in milliseconds.  `clock.sleep(seconds=1, milliseconds=500)`

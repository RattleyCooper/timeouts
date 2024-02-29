import std/[times, os]
import timeouts/timeouts


var clock: Clock = newClock()

block testDurationShorthandMacros:
  assert every(seconds=1).Duration == initDuration(seconds=1)
  assert after(milliseconds=1).Duration == initDuration(milliseconds=1)
  assert after(seconds=1) is After
  assert every(seconds=1) is Every
  assert every(seconds=1) is not Duration
  assert after(seconds=1).Duration == every(seconds=1).Duration
  assert duration(seconds=1) == initDuration(seconds=1)
  assert duration(seconds=1) is Duration

block testTimeoutProcs:
  # Do timeout procs fire too early or exist after firing?
  # Block syntax
  clock.run after(seconds=1):
    echo "timeout proc test"
    echo "this is a test"
  
  # Does it fire early?
  clock.tick()
  clock.sleep(milliseconds=100)
  clock.tick()
  assert clock.timeouts.len == 1
  assert clock.timeouts[^1] is TimeoutProc

  # Does it exist after firing?
  clock.sleep(milliseconds=1000)
  clock.tick()
  clock.tick()
  assert clock.timeouts.len == 0

  proc testTimeout1() =
    echo "Done!"

  var timeoutObj = testTimeout1.newTimeoutProc(seconds=6)
  clock.add(timeoutObj)
  assert clock.timeouts.len == 1
  assert clock.timeouts[^1] is TimeoutProc
  assert clock.timeouts[^1] == timeoutObj

block testIntervalProcs:
  # Do interval procs fire on schedule?
  # Block syntax
  var c = 1
  clock.run every(seconds=1):
    inc c

  var intervalObj = clock.intervals[^1]
  assert intervalObj is IntervalProc

  # Traditional syntax
  proc testInterval1() =
    echo "test interval " & $c
  
  var intervalObj2 = testInterval1.newIntervalProc(seconds=1)
  clock.add(intervalObj2)
  assert clock.intervals[^1] == intervalObj2
  assert clock.intervals[^1] is IntervalProc


block testNestedCallbacks:
  clock.run every(seconds=10):
    clock.run after(seconds=1):
      echo "Backup in 5"
    clock.run after(seconds=2):
      echo "Backup in 4"
    clock.run after(seconds=3):
      echo "Backup in 3"
    clock.run after(seconds=4):
      echo "Backup in 2"
    clock.run after(seconds=5):
      echo "Backup in 1"
    clock.run after(seconds=6):
      echo "Backing up data..."
      echo "Backup complete."

  clock.run after(seconds=1):
    echo "first run"
    clock.run after(seconds=1):
      echo "second run"

  # Should start echoing after 16 seconds
  clock.run after(seconds=5):
    clock.run every(seconds=10):
      clock.run after(seconds=1):
        echo "I"
        clock.run after(seconds=1):
          echo "bless"
          clock.run after(seconds=1):
            echo "the"
            clock.run after(seconds=1):
              echo "rains"
              clock.run after(seconds=1):
                echo "down"
                clock.run after(seconds=1):
                  echo "in"
                  clock.run after(seconds=1):
                    echo "Africa"

  # I would test nested `clock.run every` but I feel like
  # that's a bit much given that it's a terrible idea.

  # Schedule a quit event.
  clock.run after(seconds=60):
    quit(0)
  clock.run after(seconds=59):
    echo "Thanks for testing me!"

block runMainLoop:
  # Create loop to test our interval procs.
  clock.start()
  while true:
    clock.tick()
    clock.fsleep(20)

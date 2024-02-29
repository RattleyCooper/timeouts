## Simplify and contain your callbacks using block syntax. 
## 
## The old ways:
## 
##    var clock = newClock()
## 
##    proc test() =
##      echo "this is a traditional callback"
##      echo "that will get scattered to the wind"
## 
##    clock.add(test.timeout(every(milliseconds=400)))
## 
##    while true: clock.tick()
## 
## The next one contains the callback but readability is baaAAAaad:
## 
##   var clock = newClock()
## 
##   clock.add(
##     (proc() =
##       echo "this is ugly"
##       echo "and is hard to remember unless"
##       echo "you're a robot"
##       ).timeout(every(milliseconds=500))
##     )
## 
##    while true: clock.tick()
## 
## We can do better... :
## 
##    var clock = newClock()
##    
##    clock.run every(seconds=1):
##      echo "w00t"
## 
##    clock.run after(milliseconds=500):
##      echo "this is a better callback"
##      echo "and will make your life easier"
##      echo "you can read all the code in one place"
##      echo "and understand it at a glance.
##      
##    while true: clock.tick()
## 
## ^^^ Wow, that's super pretty!
## 
 

import std/[monotimes, times, macros, os]

type
  Every* = distinct Duration
  After* = distinct Duration

  TimeoutProc* = ref object
    callback*: proc()
    duration*: After
    lastCall*: MonoTime
    lastAttempt*: MonoTime

  IntervalProc* = ref object
    callback*: proc()
    duration*: Every
    lastCall*: MonoTime
    lastAttempt*: MonoTime

  Clock* = ref object
    timeouts*: seq[TimeoutProc]
    intervals*: seq[IntervalProc]
    startTime*: MonoTime
    lapTime*: MonoTime
    elapsed*: Duration

proc newClock*(): Clock =
  ## Create a new clock object
  #
  result = Clock()
  result.timeouts = newSeq[TimeoutProc]()
  result.intervals = newSeq[IntervalProc]()
  result.startTime = getMonoTime()
  result.lapTime = getMonoTime()
  result.elapsed = result.lapTime - result.startTime

proc reset*(clock: Clock) = 
  ## Reset the clock
  #
  clock.startTime = getMonoTime()
  clock.lapTime = getMonoTime()
  clock.elapsed = clock.lapTime - clock.startTime

proc start*(clock: Clock) = 
  ## Set the start time for the clock
  #
  clock.startTime = getMonoTime()

proc lap*(clock: Clock) =
  ## Set the lap time for the clock.
  #
  clock.lapTime = getMonoTime()
  clock.elapsed = clock.lapTime - clock.startTime

proc fsleep*(clock: Clock, milliseconds: int) = 
  ## Sleep a fixed amount of time, with processing time taken
  ## out of the total time slept.  Every time the clock ticks
  ## it will update it's internal clock.  Call clock.start()
  ## to reset the initial time value that is measured from.
  ## Great if you want a fixed amount of time for processing
  ## in an event loop.
  #
  clock.lap()
  var mil = (clock.lapTime-clock.startTime).inMilliseconds
  var sleepTime = max(milliseconds-mil, 0)
  sleep(sleepTime)
  clock.reset()

proc fsleep*(clock: Clock, time: Duration) = 
  ## Sleep a fixed amount of time, with processing time taken
  ## out of the total time slept.  Every time the clock ticks
  ## it will update it's internal clock.  Call clock.start()
  ## to reset the initial time value that is measured from.
  ## Great if you want a fixed amount of time for processing
  ## in an event loop.
  #
  clock.lap()
  var mil = (clock.lapTime-clock.startTime).inMilliseconds
  var sleepTime = max(time.inMilliseconds-mil, 0)
  sleep(sleepTime)
  clock.reset()

macro fsleep*(clock: Clock, v: varargs[untyped]): untyped =
  ## Do a fixed time sleep using the given initDuration args
  #  to set the length of the sleep time.
  #
  quote do:
    clock.fsleep(initDuration(`v`))

macro sleep*(clock: Clock, v: varargs[untyped]): untyped =
  ## Sleep for the duration defined by the args you would 
  #  normally pass to initDuration
  #  Example: clock.sleep(milliseconds=1000)
  # 
  quote do:
    sleep(initDuration(`v`).inMilliseconds)

proc newTimeoutProc*(p: proc(), d: After): TimeoutProc =
  ## Create a new timeout procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will only fire
  #  fire once. If you want repeating calls use the
  #  IntervalProc.
  #
  result = TimeoutProc()
  result.callback = p
  result.duration = d
  result.lastCall = getMonoTime()
  result.lastAttempt = getMonoTime()

proc newTimeoutProc*(p: proc(), d: Duration): TimeoutProc =
  ## Create a new timeout procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will only fire
  #  fire once. If you want repeating calls use the
  #  IntervalProc.
  #
  result = TimeoutProc()
  result.callback = p
  result.duration = d.After
  result.lastCall = getMonoTime()
  result.lastAttempt = getMonoTime()

macro newTimeoutProc*(p: proc(), d: varargs[untyped]): untyped =
  ## Create a new timeout procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will only fire
  #  fire once. If you want repeating calls use the
  #  IntervalProc.
  #
  quote do:
    newTimeoutProc(`p`, initDuration(`d`))

proc timeout*(p: proc(), d: After): TimeoutProc =
  ## Create a new timeout procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will only fire
  #  fire once. If you want repeating calls use the
  #  IntervalProc.
  #
  newTimeoutProc(p, d)

macro timeout*(p: proc(), durationArgs: varargs[untyped]): untyped =
  ## Create a new timeout procedure without needing
  ## to init a Duration manually.  Just pass in the
  ## args you would pass to initDuration.
  ## 
  #    clock.add someProc.timeout(milliseconds=500)
  #
  quote do:
    newTimeoutProc(`p`, initDuration(`durationArgs`).After)

macro timeout*(clock: Clock, d: static[After], body: untyped): untyped =
  ## Allows you to write callback procedures using blocks.
  #  This will create the callback procedure, insert the body
  #  of the block into the callback and then add it to the
  #  Clock.
  #  
  #  clock.timeout every(seconds=1):
  #    echo "This is the body of the proc"
  #    echo "and this syntax is much more"
  #    echo "easy to read and understand"
  #    echo "and we don't have to manage"
  #    echo "the clock manually"
  #
  quote do:
    `clock`.add(newTimeoutProc(proc() = `body`, `d`))

proc newIntervalProc*(p: proc(), d: Every): IntervalProc =
  ## Create a new interval procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will continue to
  #  fire after the first call.
  #
  result = IntervalProc()
  result.callback = p
  result.duration = d
  result.lastCall = getMonoTime()
  result.lastAttempt = getMonoTime()

proc newIntervalProc*(p: proc(), d: Duration): IntervalProc =
  ## Create a new interval procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will continue to
  #  fire after the first call.
  #
  result = IntervalProc()
  result.callback = p
  result.duration = d.Every
  result.lastCall = getMonoTime()
  result.lastAttempt = getMonoTime()

macro newIntervalProc*(p: proc(), d: varargs[untyped]): untyped =
  ## Create a new timeout procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will only fire
  #  fire once. If you want repeating calls use the
  #  IntervalProc.
  #
  quote do:
    newIntervalProc(`p`, initDuration(`d`))

proc interval*(p: proc(), d: Every): IntervalProc =
  ## Create a new interval procedure that will fire
  #  off when the tick procedure is called and the 
  #  elapsed time exceeds the duration. If this is
  #  registered with the Clock it will continue to
  #  fire after the first call.
  #
  newIntervalProc(p, d)

macro interval*(p: proc(), durationArgs: varargs[untyped]): untyped =
  ## Create a new interval procedure without needing
  ## to init a Duration manually.  Just pass in the
  ## args you would pass to initDuration.
  ## 
  #    clock.add someProc.interval(milliseconds=500)
  #
  quote do:
    newIntervalProc(`p`, initDuration(`durationArgs`).Every)

macro duration*(v: varargs[untyped]): untyped =
  ## Shorthand macro for initDuration.  Just feed it the
  #  same args/kwargs you'd feed to initDuration.
  #
  quote do:
    initDuration(`v`)

macro every*(v: varargs[untyped]): untyped =
  ## Shorthand macro for initDuration.  Just feed it the
  #  same args/kwargs you'd feed to initDuration.
  #
  quote do:
    initDuration(`v`).Every

macro every*(p: proc(), v: varargs[untyped]): untyped =
  quote do:
    `p`.newIntervalProc(initDuration(`v`))

macro after*(v: varargs[untyped]): untyped =
  ## Shorthand macro for initDuration.  Just feed it the
  #  same args/kwargs you'd feed to initDuration.
  #
  quote do:
    initDuration(`v`).After

macro after*(p: proc(), v: varargs[untyped]): untyped =
  ## Shorthand macro for initDuration.  Just feed it the
  #  same args/kwargs you'd feed to initDuration.
  #
  quote do:
    `p`.newTimeoutProc(initDuration(`v`))

macro interval*(clock: Clock, d: static[Duration], body: untyped): untyped =
  ## Allows you to write callback procedures using blocks.
  #  This will create the callback procedure, insert the body
  #  of the block into the callback and then add it to the
  #  Clock.
  #  
  #  clock.interval every(seconds=1):
  #    echo "This is the body of the proc"
  #    echo "and this syntax is much more"
  #    echo "easy to read and understand"
  #    echo "and we don't have to manage"
  #    echo "the clock manually"
  #
  quote do:
    `clock`.add(newIntervalProc(proc() = `body`, `d`))

macro run*(clock: Clock, d: static[Every], body: untyped): untyped =
  ## Enables the clock.run every(milliseconds=50) syntax.
  #  This creates a callback that runs on an interval.
  #
  quote do:
    `clock`.add(newIntervalProc(proc() = `body`, `d`))

macro run*(clock: Clock, d: static[After], body: untyped): untyped =
  ## Enables the clock.run after(milliseconds=50) syntax.
  #  This creates a callback that runs after a given 
  #  amount of time.
  #
  quote do:
    `clock`.add(newTimeoutProc(proc() = `body`, `d`))

proc add*(clock: Clock, tp: TimeoutProc) =
  ## Add a timeout procedure to the clock.
  #
  clock.timeouts.add(tp)

proc add*(clock: Clock, intproc: IntervalProc) =
  ## Add an interval procedure to the clock.
  #
  clock.intervals.add(intproc)

macro fires*(aft: static[After], u: untyped): untyped =
  ## Enables a {.fires: after(days=1).} pragma
  #  for procedures.  This REQUIRES a `clock` variable to
  #  exist in the code calling it.
  # 

  # Extract proc's code block from the decorated proc.
  var procBody = newStmtList()
  for n in u:
    if n.kind == nnkStmtList:
      procBody = n
      break
  
  # Add an IntervalProc to the `clock` variable using the 
  # decorated proc's code block.
  result = quote do:
    clock.add((proc()=`procBody`).newTimeoutProc(`aft`))


macro repeats*(evr: static[Every], u: untyped): untyped =
  ## Enables a {.repeats: every(milliseconds=50).} pragma
  #  for procedures.  This REQUIRES a `clock` variable to
  #  exist in the code calling it.
  # 

  # Extract proc's code block from the decorated proc.
  var procBody = newStmtList()
  for n in u:
    if n.kind == nnkStmtList:
      procBody = n
      break
  
  # Add an IntervalProc to the `clock` variable using the 
  # decorated proc's code block.
  result = quote do:
    clock.add((proc()=`procBody`).newIntervalProc(`evr`))

proc tick*[T: TimeoutProc | IntervalProc](t: T): bool =
  ## Try to fire a timeout/interval procedure.
  #
  result = false
  t.lastAttempt = getMonoTime()

  if (t.lastAttempt - t.lastCall) >= t.duration.Duration:
    t.callback()
    result = true
    t.lastCall = getMonoTime()

proc tick*(clock: Clock) = 
  ## Try to fire timeout and interval procedures,
  #  and remove timeout procedures if they were 
  #  fired.
  #

  # Loop over the timeouts seq and rotate any
  # procs that didn't fire back into the front
  # of the stack.
  clock.lap()

  for ind in 0 .. clock.timeouts.high:
    var t = clock.timeouts.pop()
    if not t.tick():
      clock.timeouts.insert(t, 0)

  # Loop over intervals seq and call the tick
  # proc on each one.
  for intproc in clock.intervals:
    discard intproc.tick()

if isMainModule:
  echo "starting test"
  var clock: Clock = newClock()

  # Make some procs to use as callbacks
  proc test() =
    echo "test!"
  proc test2() = 
    echo "test2!!!"
  proc testInterval() = 
    echo "w00t"
  proc mtest()=
    echo "macro magic!"

  # fire callback once after duration
  var someTimeoutProc = test.newTimeoutProc(milliseconds=2000)

  # fire callback repeatedly every duration
  var someIntervalProc = testInterval.newIntervalProc(milliseconds=500)
  
  # adding callbacks to the clock the old fasioned way
  clock.add(someTimeoutProc)
  clock.add(someIntervalProc)

  # timeout is shorthand for newTimeoutProc
  clock.add(test.timeout(milliseconds=500, seconds=5))
  
  # interval is shorthand for newIntervalProc
  clock.add(mtest.interval(seconds=5))

  # Note that callback procs cannot have arguments
  # but you can easily get around that
  proc someWrapper(localStr: string) =
    clock.add((proc() = echo localStr).timeout())
  
  someWrapper("This callback was wrapped!")

  # # Automatically register interval proc
  # # and use the indented section as the
  # # body of the callback procedure.
  clock.run every(seconds=10):
    echo "Do you see?"
  
  # # Automatically register timeout proc
  # # and use the indented section as the
  # # body of the callback procedure.
  clock.run after(seconds=2):
    echo "w00t w00t"

  # You can also use `every` and `after` 
  # as shorthand for timeout and interval
  clock.add(test2.every(seconds=1))

  # You can nest them as well.
  clock.run after(milliseconds=2000):
    echo "Hello"
    clock.run after(milliseconds=50):
      echo "world"

  var c = 0
  clock.run every(seconds=1):
    echo $c
    inc c

  # You must call clock.tick() in a loop,
  # or call tick() on the IntervalProc or
  # on the TimeoutProc directly
  while true:
    clock.tick()
    # Sleep for a fixed duration. This
    # includes processing time since 
    # last call to clock.tick().
    # So if it took 150ms to process
    # everything between these 2 calls
    # the fsleep proc wouldn't sleep at
    # all and if it took 80ms it would
    # sleep for 20ms.
    clock.fsleep(milliseconds=100)

globals [
  seats
  stalls
  stalls-queue
  customers-to-get-food
  customers-arrival-rate
  total-number-of-customers
  number-of-trays-returned
  number-of-tray-return-points
  number-of-unsatisfied-customers
  number-of-cleaned-trays
]

breed [ customers customer ]
breed [ cleaners cleaner ]
breed [ foods food ]
breed [ tissues tissue ]
breed [ tray-return-points tray-return-point]

customers-own [ target status to-chope? seat-choped eating-time satisfaction-level ticks-counter customer-id waiting-time is-unsatisfied?]
cleaners-own [ target status patch-to-clean cleaning-duration ticks-counter idling-time previous-idling-time productivity-cost]
foods-own [ assigned-customer-id leftover-duration ]
patches-own [ definition description occupied? ]


to setup
  clear-all

  setup-globals
  setup-world
  setup-wall
  setup-tables
  setup-stalls
  setup-agents
  setup-legend-plot
  spawn-cleaners

  reset-ticks
end

to setup-legend-plot
  ; Choose correct plot
  set-current-plot "Legend"
  clear-plot

  ; Define starting y and color
  let starts [ [ 15 orange ] [ 12 red ] [ 9 115 ] [ 6 yellow ] [ 3 red ] ]

  ; for each value in starts
  foreach starts [ start ->
    ; make a range of values starting at the initial
    ; y value from 'starts'
    let s first start
    let f s - 2.5
    let ran ( range s f -0.01 )
    create-temporary-plot-pen "temp"
    set-plot-pen-color last start

    ; draw lines at each y value to make it
    ; look like a solid drawing
    foreach ran [ y ->
      plot-pen-up
      plotxy 1 y
      plot-pen-down
      plotxy 2 y
    ]
  ]
end

to setup-globals
  set seats []
  set stalls []
  set stalls-queue []
  set customers-to-get-food []
  set total-number-of-customers 0
  set number-of-tray-return-points 0
  set number-of-unsatisfied-customers 0
  set number-of-cleaned-trays 0
  ifelse (peak-hour) [
    set customers-arrival-rate 0.168056
  ] [
    set customers-arrival-rate 0.140556
  ]
end

to setup-world
  set-patch-size 7
  resize-world 0 61 0 61
  import-drawing "background_stalls.png"

  ask patches [ set occupied? false ]
end

to setup-wall
  ask patches with [pxcor > 2 and pxcor < 59 and pycor > 2 and pycor < 59] [
    set pcolor 8
    set definition "walking-path"
  ]
  ask patches with [pxcor = 2 or pxcor = 59 and pycor > 2 and pycor < 60] [
    set pcolor blue
    set definition "wall"
  ]
  ask patches with [pycor = 2 or pycor = 59 and pxcor >= 2 and pxcor < 60] [
    set pcolor blue
    set definition "wall"
  ]

  ; setup entrance and exit
  ask patches with [pxcor = 2 and pycor >= 30 and pycor <= 33] [
    set pcolor green
    set definition "entrance"
  ]
  ask patches with [pxcor = 59 and pycor >= 30 and pycor <= 33] [
    set pcolor red
    set definition "exit"
  ]
end

to setup-stalls
  ; Set up stalls
  let top-ycor 58
  let btm-ycor 7
  let temp-xcor 3
  while [ temp-xcor < 58 ] [
    create-stall temp-xcor top-ycor
    create-stall temp-xcor btm-ycor
    set temp-xcor temp-xcor + 14
  ]
end

to create-stall [input-xcor input-ycor]
  ask patches [
    if (pxcor >= input-xcor and pxcor <= input-xcor + 13 and pycor <= input-ycor and pycor >= input-ycor - 4) [
      set-stall-color
      set definition "stall"
    ]

    if ((pxcor = input-xcor or pxcor = input-xcor + 13) and pycor <= input-ycor and pycor >= input-ycor - 4) [
      set pcolor white
    ]

    if ((pycor = input-ycor or pycor = input-ycor - 4) and pxcor >= input-xcor and pxcor <= input-xcor + 13) [
      set pcolor white
    ]

    ifelse (pycor < 31) [
      if (pycor = input-ycor + 1 and pxcor = input-xcor + 10) [
        set definition (word "stall " pxcor " " pycor)
        set stalls lput (self) stalls
        set stalls-queue lput ([]) stalls-queue
      ]
    ] [
      if (pycor = input-ycor - 4 and pxcor = input-xcor + 10) [
        set definition (word "stall " pxcor " " pycor)
        set stalls lput (self) stalls
        set stalls-queue lput ([]) stalls-queue
      ]
    ]
  ]
end

to setup-tables
  let counter 0
  let temp-xcor 5
  while [ temp-xcor < 57] [
    let temp-ycor 11

    while [ temp-ycor < 50 ] [
      if (counter = number-of-tables) [
        stop
      ]
      create-table temp-xcor temp-ycor
      set temp-ycor temp-ycor + 7
      set counter (counter + 1)
    ]

    set temp-xcor temp-xcor + 9
  ]
end

to create-table [input-xcor input-ycor]
  ask patches [
    if ((pxcor = input-xcor + 1 or pxcor = input-xcor + 5) and (pycor = input-ycor + 1 or pycor = input-ycor + 3)) [
      set-seat-color
      set seats lput self seats
      ifelse (pxcor = input-xcor + 1) [
        set description "left-seat"
      ] [
        set description "right-seat"
      ]
    ]

    if (pxcor >= input-xcor + 2 and pxcor <= input-xcor + 4 and pycor >= input-ycor and pycor <= input-ycor + 4) [
      set-table-color
    ]
  ]
end

to setup-agents
  set-default-shape customers "person"
  set-default-shape cleaners "person service"
  set-default-shape tissues "tissue"
  set-default-shape foods "food"
  set-default-shape tray-return-points "rubbish bin"
end

to spawn-customers
  let number-of-customers floor (- ln (1 - random-float 1) / customers-arrival-rate) / 12
  create-customers number-of-customers [
    setxy 1 31
    set size 3
    set color 115
    set target nobody
    set status "spawned"
    set eating-time floor (random-normal 14.02667 4.2202) * 60
    set customer-id who
    set satisfaction-level customers-satisfaction-level
    set total-number-of-customers (total-number-of-customers + 1)
    set waiting-time 0
    set is-unsatisfied? false

    occupy

    ifelse (enable-seat-hogging? = true) [
      ifelse (random-float 1 < seat-hogging-probability) [
        set to-chope? true
        set seat-choped nobody
      ] [
        set to-chope? false
        set seat-choped nobody
      ]
    ] [
      set to-chope? false
      set seat-choped nobody
    ]
  ]
end

to spawn-cleaners
  let current-show-cleaner-vision? show-cleaner-vision?
  set show-cleaner-vision? true
  repeat number-of-cleaners [
    ask one-of patches with [definition = "walking-path" and pcolor = 8] [
      sprout-cleaners 1 [ ; sprout a cleaner on
        set color red
        set size 3
        set ticks-counter 0
        set target nobody
        set status "roaming"
        set patch-to-clean nobody
        set idling-time 0
        set productivity-cost 0
        occupy
        show-cleaners-vision
      ]
    ]
  ]
  set show-cleaner-vision? current-show-cleaner-vision?
  show-cleaners-vision
end

to spawn-cleaner-within-area
  if mouse-down? [
    if ([occupied?] of patch round mouse-xcor round mouse-ycor = false and [definition] of patch round mouse-xcor round mouse-ycor = "walking-path") [
      create-cleaners 1 [
        setxy round mouse-xcor round mouse-ycor
        set color red
        set size 3
        set ticks-counter 0
        set target nobody
        set number-of-cleaners (number-of-cleaners + 1)
        set status "roaming"
        set patch-to-clean nobody
        set idling-time 0
        set productivity-cost 0
        occupy
      ]
      stop
    ]
  ]
end

to spawn-tray-return-points
  if mouse-down? [
    if ([occupied?] of patch round mouse-xcor round mouse-ycor = false and [definition] of patch round mouse-xcor round mouse-ycor = "walking-path") [
      create-tray-return-points 1 [
        setxy round mouse-xcor round mouse-ycor
        set color sky + 1
        set size 4
        set definition "tray-return-point"
        ; set target nobody
        set number-of-tray-return-points (number-of-tray-return-points + 1)
        occupy
      ]
      stop
    ]
  ]
end

to-report select-random-stall
  let rand-index random (length stalls)
  report item rand-index stalls
end

to move-customers
  ask customers [
    ; initialise customer
    if (target = nobody and status = "spawned") [
      ifelse (to-chope?) [
        ; go and find a seat to chope
        set status "choping"
        set target one-of patches with [definition = "seat" and not any? tissues-here and not any? customers-here]

        if (target = nobody) [ ; no seats
          set status "looking for seat"
          ; to change
        ]
      ] [
        ; find a stall to buy food from
        set target select-random-stall
        set status "heading to stall"
      ]
    ]

    ; seat taken before customer reaches
    if (target != nobody) [
      if ([definition] of target = "seat" and (any? customers-on target or any? tissues-on target) and patch-here != target and seat-choped = nobody) [
        set target one-of patches with [definition = "seat" and not any? tissues-here and not any? customers-here]

        if (target = nobody) [
          set status "looking for seat"
          ; to change
        ]
      ]
    ]

    ; when customer is at his target seat
    if (to-chope? and seat-choped = nobody and patch-here = target and status = "choping" and [definition] of target = "seat") [
      ask patch-here [
        ; place tissue packet
        sprout-tissues 1 [ ; chope using tissue
          set size 2
        ]
      ]

      let table-patch nobody
      if ([description] of patch-here = "left-seat") [
        set table-patch patch-at 1 0
      ]
      if ([description] of patch-here = "right-seat") [
        set table-patch patch-at -1 0
      ]
      ifelse ([definition] of table-patch = "table") [
        set target select-random-stall
        set status "heading to stall"
      ] [
        set satisfaction-level (satisfaction-level - count foods-on table-patch)

        if (satisfaction-level < 0) [ set satisfaction-level 0 ]

        ; if cleaner within vision, wait for cleaner
        ifelse (any? cleaners in-radius customers-vision) [
          set status "waiting for cleaner"
        ] [
          ; move leftovers away
          ask foods-on table-patch [
            let empty-table-patch patch-at 0 -1
            ask table-patch [
              set definition "table"
            ]
            move-to empty-table-patch
            ask empty-table-patch [
              set definition "leftovers"
            ]
          ]
          set target select-random-stall
          set status "heading to stall"
        ]
      ]
      set seat-choped patch-here
    ]

    if (status = "waiting for cleaner") [
      let table-patch nobody
      if ([description] of patch-here = "left-seat") [
        set table-patch patch-at 1 0
      ]
      if ([description] of patch-here = "right-seat") [
        set table-patch patch-at -1 0
      ]

      if ([definition] of table-patch = "table" and count my-links = 0) [
        set target select-random-stall
        set status "heading to stall"
      ]
    ]

    if (member? target stalls) [ ; check if customer is headed for a stall
      set target select-queue-patch
    ]

    if (count my-links = 0) [
      queue-up-get-food
    ]

    if (target != nobody) [
      if ([definition] of target = "seat" and target = patch-here and count my-links > 0) [
        let table-patch nobody
        if ([description] of patch-here = "left-seat") [
          set table-patch patch-at 1 0
        ]
        if ([description] of patch-here = "right-seat") [
          set table-patch patch-at -1 0
        ]
        ifelse ([definition] of table-patch = "table") [
          let my-food nobody
          ask my-links [
            set my-food one-of both-ends with [ member? self foods ]
            untie
          ]
          ask tissues-here [ die ]

          if (my-food != nobody) [
            ask my-food [
              if ([description] of patch-here = "left-seat") [
                move-to patch-at 1 0
              ]
              if ([description] of patch-here = "right-seat") [
                move-to patch-at -1 0
              ]
            ]

            set status "eating"
          ]
        ] [
          set satisfaction-level (satisfaction-level - count foods-on table-patch)

          if (satisfaction-level < 0) [ set satisfaction-level 0 ]

          ; if cleaner within vision, wait for cleaner
          ifelse (any? cleaners in-radius customers-vision) [
            set status "waiting for cleaner"
          ] [
            ; move leftovers away
            ask foods-on table-patch [
              let empty-table-patch patch-at 0 -1
              ask table-patch [
                set definition "table"
              ]
              move-to empty-table-patch
              ask empty-table-patch [
                set definition "leftovers"
              ]
            ]

            let my-food nobody
            ask my-links [
              set my-food one-of both-ends with [ member? self foods ]
              untie
            ]
            ask tissues-here [ die ]

            if (my-food != nobody) [
              ask my-food [
                if ([description] of patch-here = "left-seat") [
                  move-to patch-at 1 0
                ]
                if ([description] of patch-here = "right-seat") [
                  move-to patch-at -1 0
                ]
              ]
              set status "eating"
            ]
          ]
        ]
      ]
    ]

    if (status = "eating") [
      ; start eating
      if (ticks-counter = 0) [
        set ticks-counter ticks
      ]

      ; finished eating
      if (ticks = ticks-counter + eating-time) [
        set ticks-counter 0
        let leftover-status true
        let has-tray-return-point any? patches in-radius (2 * customers-vision) with [definition = "tray-return-point"]
        let my-food nobody
        let x xcor
        let y ycor
        ask my-links [
          set my-food one-of both-ends with [ member? self foods ]
          ask my-food [
            set color red
          ]

          ifelse (has-tray-return-point) [
            ifelse (random-float 1 < probability-of-returning-leftover) [ ; to change distribution. nearer the more likely?
              ask my-food [
                setxy x y
                set leftover-status false
              ]
              tie
            ][ ; else untie the food link and kill it
              untie
              die
            ]
          ] [
            untie
            die
          ]
        ]

        ifelse leftover-status [
          ; settings to direct customers to the exit
          set-leftovers ; set patch desc to "leftovers"
          set status "leaving"
          set target patch 61 31 ; coords of the exit
        ][
          ; settings to direct customers to the nearest tray point to dispose their leftovers
          set-non-leftovers
          set status "returning tray"
          set target min-one-of (patches with [definition = "tray-return-point"]) [distance myself] ; coords of the exit
          set number-of-trays-returned (number-of-trays-returned + 1)
        ]
      ] ; end of finished eating condition
    ] ; end of "eating" condition

    customers-throwing-leftover ; customers done throwing their leftovers and will now leave

    ; exit
    if (target = patch 61 31 and [pcolor] of patch-here = 0 and xcor > 4) [
      die
    ]

    if (status = "looking for seat") [
      set target one-of patches with [definition = "seat" and not any? tissues-here and not any? customers-here]
      ifelse (target = nobody) [
        set target one-of neighbors with [definition = "walking-path"]
        if (target = nobody) [
          set target min-one-of (patches with [definition = "walking-path"]) [distance myself]
        ]
      ] [
        ifelse (to-chope?) [
          set status "choping"
        ] [
          set status "heading to seat"
        ]
      ]
    ]

    if (satisfaction-level = 0) [
      set is-unsatisfied? true
    ]

    if (is-unsatisfied? = true) [
      set number-of-unsatisfied-customers (number-of-unsatisfied-customers + 1)

      if (count my-links = 0) [
        set status "leaving"
        set target patch 61 31

        if (seat-choped != nobody) [
          ask tissues-on seat-choped [
            die
          ]
        ]
      ]
      set satisfaction-level -1
      set is-unsatisfied? false
    ]

    move-towards target
  ]
end

to customers-throwing-leftover
  ; for those customers done throwing their leftovers, head to the exit
  if status = "returning tray" and [definition] of patch-here = "tray-return-point" and target = patch-here [
    ; kill the food when its at the tray collection point
    ask my-links [
      ask one-of both-ends with [ member? self foods ] [
        die
      ]
    ]
    set status "leaving"
    set target patch 61 31 ; coords of the exi
  ]
end

to queue-up-get-food
  ; move up queue
  let stall-num nobody
  let queue-num nobody

  foreach stalls-queue [ queue ->
    if (member? target queue) [
      set stall-num position queue stalls-queue
      set queue-num position target queue
      if (patch-here = target) [
        set status "queuing"
      ]
    ]
  ]

  ifelse (status = "queuing") [
    ifelse (queue-num = 0) [
      if (ticks-counter = 0) [
        set ticks-counter ticks
      ]

      if (ticks = ticks-counter + time-to-prepare-food) [
        set customers-to-get-food lput (self) customers-to-get-food
        set ticks-counter 0

        ifelse (seat-choped = nobody) [
          set target clean-empty-seat
          set status "heading to seat"

          if (target = nobody) [
            set target one-of neighbors with [definition = "walking-path"]
            set status "looking for seat"
            ; wait until there is a seat
            ; to change
          ]
        ] [
          set target seat-choped
          set status "heading to seat"
        ]
      ]
    ] [
      let next-queue-patch item (queue-num - 1) (item stall-num stalls-queue)

      if (count customers with [status = "queuing" and xcor = [pxcor] of next-queue-patch and ycor = [pycor] of next-queue-patch] = 0) [
        set target next-queue-patch
      ]
    ]
  ] [
    if (status = "heading to stall" and any? customers-on target) [
      ; reset target in queue
      let stall-queue (item stall-num stalls-queue)
      set target item stall-num stalls
    ]
  ]
end

to-report clean-empty-seat
  report one-of patches with [definition = "seat" and not any? tissues-here and not any? customers-here and [definition] of patch-at 1 0 != "leftovers" and [definition] of patch-at -1 0 != "leftovers"]
end


to move-towards [destination]
  unoccupy
  let my-x xcor
  let my-y ycor
  let t-x [pxcor] of destination
  let t-y [pycor] of destination

  if (my-x < t-x) [
    set heading 90
  ]

  if (my-x > t-x) [
    set heading 270
  ]

  if (my-x = t-x) [
    ifelse (my-y > t-y) [
      set heading 180
    ] [
      set heading 0
    ]
  ]

  if ([definition] of patch-ahead 1 = "wall") [
    if (my-y > t-y) [
      set heading 180
    ]
    if (my-y < t-y) [
      set heading 0
    ]
  ]
  ifelse distance target < customers-walking-speed [
    move-to target
  ] [
    fd customers-walking-speed
  ]
  occupy
end

to move-cleaner
  ask cleaners [ ; they can only move within the hawker's confinement
    show-cleaners-vision

    if (status = "roaming") [
      set patch-to-clean detect-leftovers

      ifelse (patch-to-clean = nobody) [
        let walking-path one-of neighbors with [definition = "walking-path" or definition = "queue"]

        ifelse (walking-path = nobody) [
          move-to min-one-of (patches with [definition = "walking-path" or definition = "queue"]) [distance myself]
        ] [
          move-to walking-path
        ]
      ] [
        set status "cleaning"
      ]
    ]

    if (status = "cleaning" and patch-here = target) [ ; if cleaner is beside the leftovers
      ifelse (ticks-counter = 0) [ ; start cleaning
        set ticks-counter ticks
        set cleaning-duration floor (random-normal 11.98667 2.663534)

        ask patch-to-clean [
          set description "cleaning in progress"
        ]
      ][
        if (ticks = ticks-counter + cleaning-duration) [ ; check if cleaning is done
          ask patch-to-clean [
            set-table-color
            set description 0
            set number-of-cleaned-trays number-of-cleaned-trays + count foods-here

            ask foods-here [
              die
            ]
          ]

          set target nobody
          set patch-to-clean nobody
          set ticks-counter 0
          set status "roaming"
        ]
      ]
    ]

    if (status = "cleaning" and patch-here != target) [
      ifelse ([description] of patch-to-clean = "cleaning in progress") [
        set patch-to-clean detect-leftovers

        if (patch-to-clean = nobody) [
          let walking-path one-of neighbors with [definition = "walking-path" or definition = "queue"]

          ifelse (walking-path = nobody) [
            move-to min-one-of (patches with [definition = "walking-path" or definition = "queue"]) [distance myself]
          ] [
            move-to walking-path
          ]
          set status "roaming"
        ]
      ] [
        unoccupy
        move-towards target
        occupy
      ]
    ]
  ]
end

to-report detect-leftovers
  let leftover min-one-of (patches in-radius cleaner-vision with [definition = "leftovers" and description != "cleaning in progress"]) [distance myself]

  if (leftover != nobody) [
    let temp-target nobody
    ask leftover [
      set temp-target one-of neighbors with [definition = "walking-path" or definition = "queue"] ; target walking path beside the leftovers
    ]
    set target temp-target
  ]
  report leftover
end

to show-cleaners-vision
  ask patches with [(pcolor = cyan + 4) and definition = "table"] [ set-table-color ]
  ask patches with [(pcolor = cyan + 4) and (definition = "walking-path" or definition = "queue")] [ set pcolor 8 ]
  ask patches with [(pcolor = cyan + 4) and definition = "seat"] [ set-seat-color ]

  if (show-cleaner-vision?) [
    ask cleaners [
      ask patches in-radius cleaner-vision [
        if (definition = "walking-path" or definition = "queue") [
          set pcolor cyan + 4
        ]
      ]
    ]
  ]
end

to-report select-queue-patch
  let result-patch nobody
  let stall-x [pxcor] of target
  let stall-y [pycor] of target
  let stall-queue item (position target stalls) stalls-queue

  ifelse (length stall-queue = 0) [
    set result-patch get-next-vertical-queue-patch stall-x stall-y false
  ] [
    ; check for empty patches in queue
    foreach stall-queue [ queue ->
      if (not any? customers-on queue) [
        report queue
      ]
    ]

    ; else add patch to queue
    let last-queue-patch item (length stall-queue - 1) stall-queue
    let last-queue-patch-x [pxcor] of last-queue-patch
    let last-queue-patch-y [pycor] of last-queue-patch
    let to-reverse false
    ifelse ((length stall-queue) mod 3 = 0) [
      set result-patch get-next-horizontal-queue-patch last-queue-patch-x last-queue-patch-y
    ] [
      if (floor (length stall-queue / 3) mod 2 = 1) [
        set to-reverse true
      ]
      set result-patch get-next-vertical-queue-patch last-queue-patch-x last-queue-patch-y to-reverse
    ]
  ]

  set stall-queue lput result-patch stall-queue
  set stalls-queue replace-item (position target stalls) stalls-queue stall-queue

  ask result-patch [
    set definition "queue"
  ]

  report result-patch
end

to-report get-next-horizontal-queue-patch [stall-x stall-y]
  report patch (stall-x - 1) stall-y
end

to-report get-next-vertical-queue-patch [stall-x stall-y to-reverse]
  if (not to-reverse) [
    if (stall-y < 31) [
      report patch stall-x (stall-y + 1)
    ]
    report patch stall-x (stall-y - 1)
  ]

  if (stall-y < 31) [
    report patch stall-x (stall-y - 1)
  ]
  report patch stall-x (stall-y + 1)
end

to spawn-food
  ; spawn food for each customers
  foreach customers-to-get-food [c ->
    let x [xcor] of c
    let y [ycor] of c
    create-foods 1 [
      setxy x y
      set size 2
      set color 45
      set assigned-customer-id [customer-id] of c
      create-link-with c [ tie ] ; food to follow customer
    ]
  ]
  set customers-to-get-food []

  ask foods [
    if ([pcolor] of patch-here = 0) [ die ]
  ]
end


to go
  spawn-customers
  move-customers
  move-cleaner
  spawn-food

  calculate-analytics
  tick
  ;if ticks > 5000 [stop]

end

to occupy
  ask patch-here [set occupied? true]
end
to unoccupy
  ask patch-here [set occupied? false]
end

to set-leftovers
  if ([description] of patch-here = "left-seat") [
    ask patch-at 1 0 [
      set definition "leftovers"
    ]
  ]
  if ([description] of patch-here = "right-seat") [
    ask patch-at -1 0 [
      set definition "leftovers"
    ]
  ]
end

to set-non-leftovers
  if ([description] of patch-here = "left-seat") [
    ask patch-at 1 0 [
      set definition "table"
    ]
  ]
  if ([description] of patch-here = "right-seat") [
    ask patch-at -1 0 [
      set definition "table"
    ]
  ]
end

to set-table-color ; change the color of the table
  set pcolor 56
  set definition "table"
end

to set-seat-color ; change the color of the table
  set pcolor brown
  set definition "seat"
end

to set-center-black ; set patches around the stalls to black
  set pcolor black
end

to set-stall-color
  set pcolor pink + 2
end

to set-cleaner-vision-color
  set pcolor cyan + 4
end

to calculate-analytics
  calculate-average-waiting-time
  calculate-leftover-duration
  calculate-cleaners-idling-time
  calculate-productivity-cost
end

to calculate-cleaners-idling-time
  ask cleaners [
    if (ticks mod 60 = 0) [
      set previous-idling-time idling-time
      set idling-time 0
    ]
    if (status = "roaming") [
      set idling-time (idling-time + 1)
    ]
  ]
end

to calculate-leftover-duration
  ask foods [
    if (color = red) [
      set leftover-duration (leftover-duration + 1)
    ]
  ]
end

to calculate-average-waiting-time
  ; set customer variable for this to calculate
  ask customers with [status = "looking for seat"] [
    set waiting-time (waiting-time + 1)

    if (waiting-time mod 60 = 0) [
      set satisfaction-level (satisfaction-level - 1)
    ]
  ]
end

to calculate-productivity-cost

  let unproductivity 0
  ask cleaners with [status = "roaming"] [
    set unproductivity (unproductivity + 1)
  ]

  ask cleaners [
    ifelse ticks mod 60 = 0 [
      set productivity-cost 0
    ][
      set productivity-cost (((count cleaners - unproductivity) / (count cleaners)) * 6)
    ]
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
208
10
650
453
-1
-1
7.0
1
10
1
1
1
0
1
1
1
0
61
0
61
0
0
1
ticks
30.0

BUTTON
74
13
138
46
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
665
10
884
43
number-of-tables
number-of-tables
1
36
36.0
1
1
NIL
HORIZONTAL

SLIDER
902
10
1132
43
customers-walking-speed
customers-walking-speed
0.1
2
1.0
0.1
1
NIL
HORIZONTAL

SWITCH
20
109
190
142
peak-hour
peak-hour
0
1
-1000

BUTTON
8
58
93
91
Go Once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
104
59
204
92
Go Forever
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1154
10
1348
43
number-of-cleaners
number-of-cleaners
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
902
96
1134
129
probability-of-returning-leftover
probability-of-returning-leftover
0
1
0.73
0.01
1
NIL
HORIZONTAL

SLIDER
902
53
1133
86
seat-hogging-probability
seat-hogging-probability
0
1
0.69
0.01
1
NIL
HORIZONTAL

BUTTON
1154
98
1350
131
spawn-cleaner-within-area
spawn-cleaner-within-area
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
19
154
190
187
show-cleaner-vision?
show-cleaner-vision?
1
1
-1000

SLIDER
1154
55
1349
88
cleaner-vision
cleaner-vision
1
20
8.0
1
1
NIL
HORIZONTAL

SLIDER
902
140
1134
173
customers-satisfaction-level
customers-satisfaction-level
1
30
10.0
1
1
NIL
HORIZONTAL

SLIDER
666
53
884
86
time-to-prepare-food
time-to-prepare-food
1
120
30.0
1
1
NIL
HORIZONTAL

MONITOR
667
347
861
392
Number of Customers in Premise
count customers
17
1
11

MONITOR
667
291
861
336
Total Number of Customers
total-number-of-customers
17
1
11

BUTTON
1154
140
1350
173
spawn-tray-return-points
spawn-tray-return-points
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
667
106
867
256
Legend
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS

TEXTBOX
737
221
887
239
Leftovers\n
11
0.0
1

TEXTBOX
736
179
886
197
Customer
11
0.0
1

TEXTBOX
736
158
886
176
Cleaner
11
0.0
1

TEXTBOX
736
137
886
155
Tissue
11
0.0
1

MONITOR
667
404
861
449
Number of Tray Return Points
number-of-tray-return-points
17
1
11

TEXTBOX
737
200
887
218
Food\n
11
0.0
1

SLIDER
902
184
1135
217
customers-vision
customers-vision
1
10
5.0
1
1
NIL
HORIZONTAL

PLOT
313
464
617
689
Average Leftover Duration
Ticks
Food
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -13791810 true "" "if (count foods > 0) [\n  plot mean [leftover-duration] of foods\n]"

PLOT
4
464
309
690
Average Waiting Time
ticks
Average waiting time
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if (count customers > 0) [\n  plot mean [waiting-time] of customers\n]"

PLOT
622
463
927
687
Cleaners Idling Time / min
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [previous-idling-time] of cleaners"

MONITOR
873
292
1068
337
Number of Trays Returned
number-of-trays-returned
17
1
11

PLOT
934
462
1239
686
Utilisation of Cleaners
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [(60 - previous-idling-time) / 60] of cleaners"

MONITOR
873
347
1069
392
Number of Unsatisfied Customers
number-of-unsatisfied-customers
17
1
11

PLOT
3
697
308
921
Productivity of Labor Cost
ticks
labor cost
0.0
10.0
0.0
6.0
true
false
"" ""
PENS
"default" 1.0 0 -15302303 true "" "plot mean [productivity-cost] of cleaners"

SWITCH
19
196
190
229
enable-seat-hogging?
enable-seat-hogging?
1
1
-1000

PLOT
314
697
618
920
Average Customer Satisfaction
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if (count customers > 0 ) [\n  plot mean [satisfaction-level] of customers\n]"

MONITOR
873
405
1070
450
Average Satisfaction Rate
mean [satisfaction-level] of customers
17
1
11

PLOT
625
697
927
921
Cost Analysis
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Cleaner" 1.0 0 -16777216 true "" "if number-of-cleaned-trays > 0 [\n  plot number-of-cleaned-trays / ( 1500 * number-of-cleaners / 60 / 60 / 14 / 30 * ticks )\n]"
"Return Point" 1.0 0 -7500403 true "" "if number-of-trays-returned > 0 and number-of-tray-return-points > 0 [\n  plot number-of-trays-returned / (( 400 * number-of-tray-return-points) + ( number-of-tray-return-points / 60 / 60 / 14 / 30 * ticks))\n]"

MONITOR
1084
292
1297
337
Number of Trays Cleared by Cleaners
number-of-cleaned-trays
17
1
11

PLOT
934
698
1239
921
Number of Unsatisfied Customers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot number-of-unsatisfied-customers"

@#$#@#$#@
## WHAT IS IT?

IS418 Agent-Based Modelling & Simulation

Team 9

## HOW IT WORKS

On 'Setup', 

When 'Go Once' is clicked, 

## HOW TO USE IT

Press…
“Setup” - initialises the simulation
“Go Once” - 
"Go Forever" - 
## CREDITS AND REFERENCES

Ng Jun Xiang 
junxiang.ng.2016@sis.smu.edu.sg

Melvin Ng
melvin.ng.2016@sis.smu.edu.sg

Sean Hoon
sean.hoon.2016@sis.smu.edu.sg
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

food
false
0
Polygon -7500403 true true 30 105 45 255 105 255 120 105
Rectangle -7500403 true true 15 90 135 105
Polygon -7500403 true true 75 90 105 15 120 15 90 90
Polygon -7500403 true true 135 225 150 240 195 255 225 255 270 240 285 225 150 225
Polygon -7500403 true true 135 180 150 165 195 150 225 150 270 165 285 180 150 180
Rectangle -7500403 true true 135 195 285 210

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person service
false
0
Polygon -2674135 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -2674135 true false 120 90 105 90 60 195 90 210 120 150 120 195 180 195 180 150 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Polygon -2674135 true false 123 90 149 141 177 90
Circle -2674135 true false 110 5 80
Line -2674135 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -2674135 true false 180 90 195 90 183 160 180 195 150 195 150 135 180 90
Polygon -2674135 true false 120 90 105 90 114 161 120 195 150 195 150 135 120 90
Polygon -2674135 true false 155 91 128 77 128 101
Rectangle -2674135 true false 118 129 141 140
Polygon -2674135 true false 145 91 172 77 172 101
Rectangle -2674135 true false 105 90 180 105
Rectangle -2674135 true false 120 195 150 210
Rectangle -2674135 true false 150 195 180 210
Rectangle -2674135 true false 135 75 165 105
Polygon -1 true false 133 90 125 90 171 90 149 118 127 91 155 102
Rectangle -1 true false 141 91 155 103
Polygon -1 true false 125 89 149 91 140 101 125 90 134 90
Polygon -1 true false 60 195 89 209 129 126 96 106 59 196 68 174
Polygon -1 true false 170 120 202 106 240 196 209 211 201 199
Rectangle -1 true false 119 187 181 202

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

rubbish bin
false
0
Circle -7500403 true true 75 90 30
Circle -7500403 true true 195 90 30
Circle -7500403 true true 165 225 30
Circle -7500403 true true 105 225 30
Circle -1 true false 135 75 30
Polygon -13791810 true false 105 240 195 240 210 105 90 105
Polygon -11221820 true false 90 105 120 105 120 240 105 240
Polygon -13345367 true false 150 105 150 240 180 240 180 105
Polygon -11221820 true false 180 105 210 105 195 240 180 240
Polygon -7500403 true true 105 240 120 255 180 255 195 240
Polygon -7500403 true true 90 90 210 90 225 105 75 105

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tissue
true
0
Rectangle -955883 true false 75 105 225 195
Rectangle -1 true false 105 135 195 165

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

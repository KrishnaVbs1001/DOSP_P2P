use "random"
use "collections"
use "time"

use @exit[None](status: I32)

actor Main
  new create(env: Env) =>
    let args = env.args
    try
      let tot_nds: USize = args(1)?.usize()?
      let tot_req: USize = args(2)?.usize()?

      env.out.print("Initializing Chord simulation with " +
        tot_nds.string() + " nodes and " + tot_req.string() + " requests per node.")
      
      ChordNetwork(tot_nds, tot_req, env).initialize_network()
    else
      display_usage(env)
    end

  fun display_usage(env: Env) =>
    env.out.print("Incorrect usage. Please run as: ./chord <total_nodes> <tot_req>")


actor ChordNetwork
  let nodes: Array[Node]
  let environment: Env
  let tot_nds: USize
  let tot_req: USize
  var total_hops: USize = 0
  var completed_tasks: USize = 0
  let timer_scheduler: Timers = Timers
  let random_generator: Random

  new create(tot_nds_count: USize, total_request_count: USize, environment': Env) =>
    nodes = Array[Node](tot_nds_count)
    tot_nds = tot_nds_count
    tot_req = total_request_count
    environment = environment'
    random_generator = Rand
  
  be begin_requests() =>
    for node in nodes.values() do
      node.send_requests(tot_req)
    end

  be record_hops(hop_count: USize) =>
    total_hops = total_hops + hop_count
    completed_tasks = completed_tasks + 1

    if completed_tasks == (tot_nds * tot_req) then
      //environment.out.print("Calling log")
      log_statistics()
    end

  be log_statistics() =>
    let avg_hops = total_hops.f64() / completed_tasks.f64()
    environment.out.print("Total requests processed: " + completed_tasks.string())
    environment.out.print("Total hops traversed: " + total_hops.string())
    environment.out.print("Average hops per request: " + avg_hops.string())
    graceful_exit()

  be initialize_network() =>
    for index in Range(0, tot_nds) do
      nodes.push(Node(index, tot_nds.isize().bitwidth(), this))
    end
    for node in nodes.values() do
      node.connect_to_network(this)
    end

    let start_timer = Timer(object iso is TimerNotify
      let chord_network: ChordNetwork = this
      fun ref apply(timer: Timer, count: U64): Bool =>
        chord_network.begin_requests()
        false
    end, Nanos.from_seconds(2))
    timer_scheduler(consume start_timer)
  
  be select_random_node(requesting_node: Node tag) =>
    try
      let random_index = random_generator.int(nodes.size().u64()).usize()
      requesting_node.handle_random_node(nodes(random_index)?)
    end

  be fetch_specific_node(nid: USize, requesting_node: Node tag) =>
    try
      requesting_node.handle_node(nodes(nid)?)
    end

  be graceful_exit() =>
    let exit_timer = Timer(object iso is TimerNotify
      fun ref apply(timer: Timer, count: U64): Bool =>
        @exit(I32(0))
        false
    end, Nanos.from_seconds(3))
    timer_scheduler(consume exit_timer)


actor Node
  let nid: USize
  var nn: USize
  var pn: (USize | None) = None
  let bs: USize
  var fngtab: Array[USize]
  var req_iss: USize = 0
  var req_hand: USize = 0
  let crd: ChordNetwork tag
  let rng: Random
  let timer_schedulers: Timers = Timers

  new create(nid': USize, bs': USize, crd': ChordNetwork tag) =>
    nid = nid'
    bs = bs'
    fngtab = Array[USize].init(0, bs')
    nn = nid
    crd = crd'
    rng = Rand

  be connect_to_network(crd': ChordNetwork tag) =>
    crd'.select_random_node(this)

  be handle_random_node(node: Node tag) =>
    update_fngtab(node)

  be handle_node(node: Node tag) =>
    None

  be send_requests(num: USize) =>
    var key: USize = rng.int(((1 << bs) - 1).u64()).usize()
    var should_schedule: Bool = req_iss < num
    
    if should_schedule then
        locate_successor(key, this)
        req_iss = req_iss + 1
        
        let timer = Timer(
            object iso is TimerNotify
                let node: Node = this
                let total_requests: USize = num
                
                fun ref apply(timer: Timer, count: U64): Bool =>
                    if req_iss < num then
                        node.send_requests(total_requests)
                    end
                    false 
            end
        , Nanos.from_seconds(1))

        timer_schedulers(consume timer)
    end

  be locate_successor(key: USize, requesting_node: Node tag, idx: (USize | None) = None) =>
    let hop_count = rng.int(3).usize() + 1
    let key_in_range = in_range(key, nid, nn)
    
    if not key_in_range then
      requesting_node.notify_successor(nn, hop_count)
    else
      match idx
      | let index: USize => requesting_node.acknowledge_successor(nn, index)
      else
        requesting_node.notify_successor(nn, hop_count)
      end
    end

  fun in_range(key: USize, start: USize, end': USize): Bool =>
    if start < end' then
      (key > start) and (key < end')
    else
      (key > start) or (key < end')
    end

  be notify_successor(s: USize, hops: USize) =>
    req_hand = req_hand + 1
    crd.record_hops(hops)

  fun ref nearest_preceding_node(key: USize): USize =>
    for index in Range(0, bs) do
      try
        let finger_id = fngtab(index)?
        if (finger_id != nid) and in_range(finger_id, nid, key) then
            return finger_id
        end
      end
    end
    nn

  be acknowledge_successor(s: USize, i: (USize | None) = None) =>
    match i
    | let index: USize =>
      try
        fngtab(index)? = s
        if index == 0 then
          nn = s
        end
      end
    end

  fun ref update_fngtab(random_node: Node tag) =>
    var index: USize = 0
    while index < bs do
        let offset = (nid + (1 << index)) % (1 << bs)
        random_node.locate_successor(offset, this, index)
        index = index + 1
    end
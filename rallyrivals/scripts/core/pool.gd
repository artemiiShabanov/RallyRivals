extends RefCounted
## Generic node pool (code-core-pooling, perf-first rule). Recycles a bounded set of nodes so hot
## systems never churn allocations mid-race. Intentionally has NO class_name — consumers (incl. the
## Sfx autoload) preload() it by path, so it never depends on the global class registry (which lags
## newly-created scripts in an open editor and would parse-error an autoload until a restart).
##
## Policy (matches the hand-rolled Sfx pool it replaces): acquire() hands back an AVAILABLE node if one
## exists; else grows by one up to `cap`; else, at cap, STEALS round-robin (bounded — never allocates
## past cap). "Available" is decided one of two ways:
##   - busy-predicate (self-recycling): pass `busy` — a Callable(node)->bool. A node is available when
##     it is not busy (e.g. an AudioStreamPlayer that isn't `playing`, a GPUParticles3D not `emitting`).
##     Nothing to release; the node recycles itself. This is the Sfx model.
##   - explicit release: omit `busy`. acquire() marks a node taken; the caller calls release(node) when
##     done (e.g. a one-shot effect after its lifetime timer). Best when there is no natural busy signal.
##
## The pool never frees nodes; `host` owns them for the pool's lifetime. Stolen/reused nodes are handed
## back as-is — the caller reconfigures on acquire (set stream/position/emitting), exactly like before.

var _factory: Callable          ## () -> Node — makes a fresh pooled node
var _host: Node                 ## pooled nodes are parented here (kept out of the way, reused in place)
var _cap: int
var _busy: Callable             ## optional (node) -> bool; invalid = explicit-release mode
var _nodes: Array[Node] = []
var _taken := {}                ## explicit mode: node -> true while acquired (until release)
var _steal := 0

func _init(factory: Callable, host: Node, cap: int, busy := Callable()) -> void:
	_factory = factory
	_host = host
	_cap = maxi(cap, 1)
	_busy = busy

## Create up to n nodes up front (capped), so the first busy moment doesn't allocate.
func prewarm(n: int) -> void:
	for _i in mini(n, _cap):
		_grow()

func size() -> int:
	return _nodes.size()

func nodes() -> Array[Node]:
	return _nodes

## Hand back an available node — reuse, else grow to cap, else steal round-robin (bounded).
func acquire() -> Node:
	for node in _nodes:
		if _available(node):
			return _take(node)
	if _nodes.size() < _cap:
		return _take(_grow())
	_steal = (_steal + 1) % _nodes.size()   # at cap: steal the next in rotation (approx. oldest use)
	return _nodes[_steal]

## Return an explicitly-acquired node to the pool (no-op in busy-predicate mode).
func release(node: Node) -> void:
	_taken.erase(node)

func _grow() -> Node:
	var node: Node = _factory.call()
	if _host != null and node.get_parent() == null:
		_host.add_child(node)
	_nodes.append(node)
	return node

func _available(node: Node) -> bool:
	if _busy.is_valid():
		return not bool(_busy.call(node))
	return not _taken.has(node)

func _take(node: Node) -> Node:
	if not _busy.is_valid():
		_taken[node] = true
	return node

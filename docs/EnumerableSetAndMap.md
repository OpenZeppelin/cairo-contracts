# Enumerable Set and Map

This is a port over of Solidity's [EnumerableSet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol) and [EnumerableMap](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol). The difference in these implementation is the use of a `setId` and `mapId` but you can just think of them as defining the variables.

## Table of Contents

- [Usage](#usage)
- [EnumerableSet Spec](#enumerable-set-spec)
    - [Methods](#set-methods)
        - [`contains`](#set-contains)
        - [`add`](#set-add)
        - [`remove`](#set-remove)
        - [`length`](#set-length)
        - [`at`](set-#at)
        - [`values`](#set-values)
- [EnumerableMap Spec](#enumerable-map-spec)
    - [Methods](#map-methods)
      - [`set`](#map-set)
      - [`remove`](#map-remove)
      - [`contains`](#map-contains)
      - [`length`](#map-length)
      - [`at`](#map-at)
      - [`tryGet`](#map-tryget)
      - [`get`](#map-get)

## Usage

These utility struts are used to efficiently store either collections of data or key-value pairs. Unlike in the Solidity versions you define a `set_id` or `map_id` for each set or map that you want to declare like what is done in the [EnumerableSet_Mock](../tests/mocks/enumerableset_mock.cairo) and [EnumerableMap_Mock](../tests/mocks/enumerablemap_mock.cairo).

Note that because under the hood EnumerableMap uses EnumerableSet that if using both EnumerableSet and EnumerableMap you can have a clashing of `ids` and should pick differing ones.

## EnumerableSet Spec

<h3 id="set-methods">Methods</h3>

```cairo
func contains(set_id: felt, value: felt) -> (contains: felt):
end

func add(set_id: felt, value: felt) -> (success: felt):
end

func remove(set_id: felt, value: felt) -> (success: felt):
end

func length(set_id: felt) -> (length: felt):
end

func at(set_id: felt, index: felt) -> (value: felt):
end

func values(set_id: felt) -> (res: felt*):
end
```

<h4 id="set-contains"><code>contains</code></h3>

Returns if the set with `set_id` has `value` as `1` representing a bool if it succeeds.

Parameters:

```cairo
set_id: felt
value: felt
```

Returns:

```cairo
contains: felt
```

<h4 id="set-add"><code>add</code></h3>

Adds `value` to set with `set_id` and returns `1` representing a bool if it succeeds.

Parameters:

```cairo
set_id: felt
value: felt
```

Returns:

```cairo
success: felt
```

<h4 id="set-remove"><code>remove</code></h3>

Removes `value` from set with `set_id` and returns `1` representing a bool if it succeeds.

Parameters:

```cairo
set_id: felt
value: felt
```

Returns:

```cairo
success: felt
```

<h4 id="set-length"><code>length</code></h3>

Returns the number of elements in the set with `set_id`.

Parameters:

```cairo
set_id: felt
```

Returns:

```cairo
length: felt
```

<h4 id="set-at"><code>at</code></h3>

Returns the value at `index` in set with `set_id`.

Parameters:

```cairo
set_id: felt
index: felt
```

Returns:

```cairo
value: felt
```

<h4 id="set-values"><code>values</code></h3>

Returns a list of `values` held by set with `set_id`.

Parameters:

```cairo
set_id: felt
```

Returns:

```cairo
res: felt*
```

## EnumerableMap Spec

<h3 id="map-methods">Methods</h3>

```cairo
func set(map_id: felt, key: felt, value: felt) -> (success: felt):
end

func remove(map_id: felt, key: felt) -> (success: felt):
end

func contains(map_id: felt, key: felt) -> (contains: felt):
end

func length(map_id: felt) -> (length: felt):
end

func at(map_id: felt, index: felt) -> (key: felt, value: felt):
end

func try_get(map_id: felt, key: felt) -> (contains: felt, value: felt):
end

func get(map_id: felt, key: felt) -> (contains: felt, value: felt):
end
```

<h4 id="map-set"><code>set</code></h3>

Sets `value` for `key` in a map with `map_id` returning `1` to represent a bool if it succeeds.

Parameters:

```cairo
map_id: felt
key: felt
value: felt
```

Returns:

```cairo
success: felt
```

<h4 id="map-remove"><code>remove</code></h3>

Removes entry for `key` in a map with `map_id` returning `1` to represent a bool if it succeeds.

Parameters:

```cairo
map_id: felt
key: felt
```

Returns:

```cairo
success: felt
```

<h4 id="map-contains"><code>containes</code></h3>

Returns if the map with `map_id` has an entry for `key` as `1` representing a bool if it succeeds.

Parameters:

```cairo
map_id: felt
key: felt
```

Returns:

```cairo
contains: felt
```

<h4 id="map-length"><code>length</code></h3>

Returns the number of elements in the map with `map_id`.

Parameters:

```cairo
map_id: felt
```

Returns:

```cairo
length: felt
```

<h4 id="map-at"><code>at</code></h3>

Returns the value at `index` in map with `map_id`.

Parameters:

```cairo
map_id: felt
index: felt
```

Returns:

```cairo
value: felt
```

<h4 id="map-tryget"><code>try_get</code></h3>

Returns the value for `key` in map with `map_id` and a boolean if it contains the value or not.

Parameters:

```cairo
map_id: felt
key: felt
```

Returns:

```cairo
contains: felt
value: felt
```

<h4 id="map-get"><code>get</code></h3>

Returns the value for `key` in map with `map_id` and a boolean if it contains the value or not. This version throws if an entry for `key` does not exist.

Parameters:

```cairo
map_id: felt
key: felt
```

Returns:

```cairo
contains: felt
value: felt
```

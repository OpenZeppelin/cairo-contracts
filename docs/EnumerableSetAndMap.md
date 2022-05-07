# Enumerable Set and Map

This is a port over of Solidity's [EnumerableSet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableSet.sol) and [EnumerableMap](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/EnumerableMap.sol). The difference in these implementation is the use of a `setId` and `mapId` but you can just think of them as defining the variables.

## Table of Contents

- [Usage](#usage)
- [EnumerableSet Spec](#enumerable-set-spec)
    - [Methods](#methods)
        - [`contains`](#contains)
        - [`add`](#add)
        - [`remove`](#remove)
        - [`length`](#length)
        - [`at`](#at)
        - [`values`](#values)
- [EnumerableMap Spec](#enumerable-map-spec)
    - [Methods](#methods)

## Usage

These utility struts are used to efficiently store either collections of data or key-value pairs. Unlike in the Solidity versions you define a `set_id` or `map_id` for each set or map that you want to declare like what is done in the [EnumerableSet_Mock](../tests/mocks/enumerableset_mock.cairo) and [EnumerableMap_Mock](../tests/mocks/enumerablemap_mock.cairo).

Note that because under the hood EnumerableMap uses EnumerableSet that if using both EnumerableSet and EnumerableMap you can have a clashing of `ids` and should pick differing ones.

## EnumerableSet Spec

### Methods

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

#### `contains`

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

#### `add`

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

#### `remove`

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

#### `length`

Returns the number of elements in the set with `set_id`.

Parameters:

```cairo
set_id: felt
```

Returns:

```cairo
length: felt
```

#### `at`

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

#### `values`

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

### Methods

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

#### `set`

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

#### `remove`

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

#### `contains`

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

#### `length`

Returns the number of elements in the map with `map_id`.

Parameters:

```cairo
map_id: felt
```

Returns:

```cairo
length: felt
```

#### `at`

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

#### `try_get`

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

#### `get`

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

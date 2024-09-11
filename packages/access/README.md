## Access Control

> **NOTE:** This document is better viewed at https://docs.openzeppelin.com/contracts-cairo/api/access

This crate provides ways to restrict who can access the functions of a contract or when they can do it.

- `Ownable` is a simple mechanism with a single "owner" role that can be assigned to a single contract (usually an account). This mechanism
can be useful in simple scenarios, but fine grained access needs are likely to outgrow it.

- `AccessControl` provides a general role based access control mechanism. Multiple hierarchical roles can be created
and assigned each to multiple accounts.

### Interfaces

- `IAccessControl`

### Components

- `OwnableComponent`
- `AccessControlComponent`

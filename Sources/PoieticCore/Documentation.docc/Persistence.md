# Persistence

Persistence of a design - storing from and restoring to a file system.

## Overview

A design can be and is expected to be persisted on a file system.
Current implementation stores the content of the design as a single JSON
file with several collections of objects.

## Topics

### Store

- ``MakeshiftDesignStore``
- ``Design/restoreAll(from:)``
- ``Design/restoreAll(store:)``
- ``Design/saveAll(to:)``
- ``Design/writeAll(store:)``

See also: <doc:ForeignInterfaces>

# Out-of-scope Features

Summary:

- Performance
- Human Editable Data Files

## Performance

Primary goal of the library (and related libraries) is an implementation that is understandable
and explainable. That also implies clarity of data structures and data flows.

Performance is secondary and should be considered only when really necessary.

## Human Editable Data Files

Priority is full and open specification of persistence and interchange formats. The formats
should be non-ambiguous and should focus on preventing errors as much as possible.

Human-modifiable textual representation, for example a domain specific language in textual form,
would require complex parsing, might contain a lot of potential error types, is difficult to make
future-proof. Most importantly: it is more difficult to achieve openness of the format:
it is non trivial for others to implement correct conformance to a complex DSL.

Special case: storage and interchange format should be inspectable and repairable by third-party
tools that are not part of the Poietic toolkit. For example, JSON is editable by the `jq` tool.
If we decide to go with relational storage, we can consider SQLite - very common database, used
for data files.

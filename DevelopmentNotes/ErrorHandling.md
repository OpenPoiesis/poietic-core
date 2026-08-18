# Error Handling

There should be a strict distinction between a _programming_ error and _user_ error.

**Programming errors** must not happen at any cost, they are guarded by preconditions
and asserts. Programming errors are errors that prevent further continuation of the
program in a meaningful and consistent way.

_Example:_ Errors with user input are not programming errors.


**User errors** (issues) must be handled and presented to the user.

Requirements for representing user errors:

- Errors should be descriptive and it is recommended that they are accompanied
  with a hint how to remove them.
- If there is a potential for multiple user errors, then as many errors should be
  gathered as possible and presented to the user.
- Context of the error must be included if known, for example an object that
  caused the error.

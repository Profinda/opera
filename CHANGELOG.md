# Opera Changelog

### 0.3.4 - February 19, 2025

- Add support for `benchmark` label
- Add support for instrumentation

### 0.3.3 - January 15, 2025

- Fix issue with handling exceptions in nested operations

### 0.3.2 - December 16, 2024

- Fix issue with step method definition overriding context

### 0.3.1 - October 10, 2024

- change minor ruby version to align it with specs

### 0.3.0 - September 20, 2024

- add new syntax for context, params and dependencies readers and accessors

### 0.2.18 - September 20, 2024

- added `output!` method on Result object
- deleted `to_h` alias for `output`

### 0.2.17 - July 8, 2024

- minor fix `mode` configuration option.

### 0.2.16 - June 8, 2024

- add `mode` configuration option. When set to `:production` we optimize memory usage by skipping storing executions.

### 0.2.15 - September 4, 2023

- Make the Transaction executor work with the keyword arguments

### 0.2.14 - April 25, 2023

- Added support for objects responding to `to_hash` method in error handling for easier integration with Rails.

### 0.2.13 - October 24, 2022

- Avoid return inside transaction block to support activegraph with jruby

### 0.2.12 - Oct 24, 2022

- added support for JRuby

### 0.2.11 - June 1, 2022

- handle internally exceptions from schema

### 0.2.10 - June 1, 2022

- `finish!` does not break transaction

### 0.2.9 - May 16, 2022

- Improve executions for failing operations

### 0.2.8 - December 7, 2021

- Fix issue with default value
- Update Readme

### 0.2.7 - October 29, 2021

- Adds `finish_if` step to DSL

### 0.2.6 - October 29, 2021

- New method Result#failures that returns combined errors and exceptions

### 0.2.5 - August 3, 2021

- make sure that `default` option in accessors is always lambda

### 0.2.4 - July 26, 2021

- prevent default from overwrite falsy values
- allow params and dependencies to get defaults

### 0.2.3 - July 26, 2021

- Support context, params and dependencies accessors
- Removed depreceted `finish` method. Please use `finish!` from today

## 0.2.2 - July 7, 2021

- Test release using Github Actions

## 0.2.1 - July 7, 2021

- Support for transaction options

## 0.1.0 - September 12, 2020

- Initial release

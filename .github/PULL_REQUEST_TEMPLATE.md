## Summary

Describe the problem and the change.

## Validation

- [ ] `swipl -q -s tests/run_tests.pl`
- [ ] Added or updated regression coverage
- [ ] Documented user-visible or storage-format changes
- [ ] No private databases, credentials, generated binaries, or unrelated files
- [ ] Every commit includes a DCO `Signed-off-by` line

## Integrity and Compatibility

Describe effects on SQL compatibility, persistence, recovery, memory usage,
indexes, imports, and existing `.asa` databases. Write `None` where an area is
not affected.

## Measurements

For performance changes, include commands, environment, dataset size, elapsed
time, peak memory, baseline, and updated result. Otherwise write `Not applicable`.

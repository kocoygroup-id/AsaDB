# AsaDB Governance

AsaDB currently uses a maintainer-led governance model.

## Roles

- **Users** run AsaDB and provide feedback.
- **Contributors** submit issues, tests, documentation, designs, or code.
- **Reviewers** provide consistent technical review in an area of the project.
- **Maintainers** merge changes, manage releases, enforce community policy,
  and make final scope and compatibility decisions.

Repeated high-quality participation may lead to reviewer or maintainer access.
Access is based on trust, technical judgment, collaboration, and sustained
involvement rather than commit count alone.

## Decision Making

Routine decisions are made through issue and pull-request review. Storage
format changes, SQL compatibility breaks, major dependencies, and security
boundaries should begin with a public design issue. Maintainers make the final
decision after considering compatibility, integrity, performance evidence,
maintenance cost, and community feedback.

## Releases

Maintainers publish versioned source and binary releases. Each binary release
must identify and provide access to its complete corresponding source. Release
notes must distinguish measured results from goals and describe known limits.

## Independence

The GPL permits forks. A fork must follow the license and must not imply that
it is an official AsaDB release when it is not maintained by the AsaDB project.

# Tests

Purpose: hold project-construction tests that support AICR-Bench public documentation and tooling.

This directory is the validation layer. It is separate from the public command
surface under `scripts/`.

## Directory Contract

- `fixtures/`: small synthetic or curated inputs with known expected outputs.
- `scripts/`: test-only helpers that validate fixtures, renderer behavior, or
  documentation examples.
- `scripts/docs/` is deliberately outside this tree because it is the reusable
  public-docs framework, not a fixture-specific validator.

## Boundary

Test helpers may be invoked by executable documentation, but they are not
operator commands. Do not add `tests/scripts` helpers to `man/README.md`, and
do not describe them as user-facing module APIs.

This separation is intentional: future distributions can publish canonical
operator docs and `scripts/` while keeping `tests/` as the project-validation
suite for authors and maintainers.

Study publication gates live in the public-docs hygiene check because they
enforce public documentation hygiene. Known-answer checks live here because
they assert renderer math or report shape against committed fixture inputs.

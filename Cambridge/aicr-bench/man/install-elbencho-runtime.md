# install-elbencho-runtime.sh

## Purpose

Preview or install the shared Elbencho runtime image used by the benchmark
profiles.

## Usage

```text
scripts/benchmark/install-elbencho-runtime.sh [--method container|static] [--tag <tag>] [--image <path>] [--apply]
```

The Make entrypoint is:

```bash
make install-elbencho
```

## Options

- `--method <name>`: `container` or `static`. The supported campaign path is `container`.
- `--tag <tag>`: Upstream Elbencho container tag.
- `--image <path>`: Output Apptainer image path.
- `--apply`: Pull and verify the image. Omit for dry-run preview.
- `--help`: Print help.

## Examples

Preview the default container install:

```bash
make install-elbencho
```

Install the runtime image:

```bash
make install-elbencho APPLY=1
```

## Notes

The Elbencho image is optional and is not pulled by the default container
install workflow. Build or pull it before Elbencho setup-gate smoke,
install-smoke coverage, or benchmark rows when using a private runtime root.

The static method is documented as a CPU/filesystem fallback only. It is not the
supported GPU/GDS-capable campaign path.

# install.sh

## Purpose

Install the `aicr-bench` distribution tree into a target prefix.

## Usage

```text
./install.sh --prefix=/path/to/install
```

The installed tree is created at `/path/to/install/aicr-bench`.

## Options

- `--prefix <path>` or `--prefix=<path>`: Required destination prefix.
- `-h`, `--help`: Print usage.

## Outputs

- Copies the `aicr-bench` software tree into the requested prefix.
- Does not build Python environments or pull containers.

## Examples

Install under a shared work directory:

```bash
./install.sh --prefix=/work/aicr/commissioning/benchmarks/aicr-bench-tests/install-demo
```

Prepare the installed checkout:

```bash
cd /work/aicr/commissioning/benchmarks/aicr-bench-tests/install-demo/aicr-bench
cp benchmark-settings.env.example benchmark-settings.env
make setup-python-local
make doctor-python
```

## Notes

Run the installer from the `Cambridge/` directory in the public repository.

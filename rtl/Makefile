PYTHON ?= ../.venv/bin/python

.PHONY: check generated inventory synth-check clean
check:
	$(PYTHON) scripts/check_vhdl.py
generated:
	$(PYTHON) scripts/emit_config.py --check
	$(PYTHON) scripts/emit_smoke_tb.py --check
inventory:
	$(PYTHON) scripts/check_scaffold.py
synth-check:
	$(PYTHON) scripts/check_scaffold.py --require-implemented eat_fpga_top
clean:
	rm -rf build

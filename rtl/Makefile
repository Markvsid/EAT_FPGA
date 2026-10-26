PYTHON ?= ../.venv/bin/python

.PHONY: check functional synthesis-frontend generated inventory synth-check clean
check:
	$(PYTHON) scripts/check_vhdl.py
functional:
	$(PYTHON) scripts/test_rtl.py
	$(PYTHON) scripts/test_images.py
synthesis-frontend:
	$(PYTHON) scripts/check_synth_frontend.py
generated:
	$(PYTHON) scripts/emit_config.py --check
	$(PYTHON) scripts/emit_smoke_tb.py --check
inventory:
	$(PYTHON) scripts/check_scaffold.py
synth-check:
	$(PYTHON) scripts/check_scaffold.py --require-implemented eat_fpga_top
clean:
	rm -rf build

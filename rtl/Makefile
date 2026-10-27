PYTHON ?= ../.venv/bin/python

.PHONY: check functional integration synthesis-frontend synthesis-integration generated inventory synth-check clean
check:
	$(PYTHON) scripts/check_vhdl.py
functional:
	$(PYTHON) scripts/test_rtl.py
integration:
	$(PYTHON) scripts/test_rtl.py --suite core --suite system
synthesis-frontend:
	$(PYTHON) scripts/check_synth_frontend.py
synthesis-integration:
	$(PYTHON) scripts/check_synth_frontend.py --integration
generated:
	$(PYTHON) scripts/emit_config.py --check
	$(PYTHON) scripts/emit_image_pkg.py --check
inventory:
	$(PYTHON) scripts/check_scaffold.py
synth-check:
	$(PYTHON) scripts/check_scaffold.py --require-implemented eat_fpga_top
clean:
	rm -rf build

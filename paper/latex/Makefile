PYTHON ?= python3

.PHONY: check refresh pdf package clean
check:
	$(PYTHON) scripts/check_project.py
refresh:
	$(PYTHON) scripts/refresh_evidence.py
pdf: check
	$(PYTHON) scripts/build.py
package: check
	$(PYTHON) scripts/package_overleaf.py
clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('build', ignore_errors=True)"

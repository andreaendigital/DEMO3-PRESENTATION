.PHONY: help setup docs docs-build docs-deploy clean

help:
	@echo "DEMO3 Presentation Documentation"
	@echo "======================================"
	@echo "Available commands:"
	@echo "  setup       - Install all dependencies"
	@echo "  docs        - Start local documentation server"
	@echo "  stop        - Stop documentation server"
	@echo "  docs-build  - Build static documentation"
	@echo "  docs-deploy - Deploy to GitHub Pages"
	@echo "  check       - Verify setup and configuration"
	@echo "  clean       - Clean build artifacts"

setup:
	@echo "Setting up DEMO3 Presentation..."
	@echo "===================================="
	@echo "Checking Python..."
	@python3 --version || python --version || (echo "Python not found" && exit 1)
	@python3 -c "import sys; exit(0 if sys.version_info >= (3, 9) else 1)" || (echo "Python 3.9+ required" && exit 1)
	@echo "Checking pip..."
	@pip --version || (echo "pip not found" && exit 1)
	@echo "Upgrading pip..."
	@pip install --upgrade pip
	@echo "Installing documentation dependencies..."
	@pip install -e .[dev]
	@echo "Setup complete! Try: make docs"

docs:
	@echo "Starting Documentation Development Server..."
	@echo "=============================================="
	@if ! command -v mkdocs >/dev/null 2>&1; then \
		echo "Installing MkDocs..."; \
		pip install mkdocs-material mkdocs-git-revision-date-localized-plugin pymdown-extensions; \
	fi
	@echo "Checking for existing server on port 8000..."
	@lsof -ti:8000 | xargs kill -9 2>/dev/null || true
	@sleep 1
	@echo "Documentation server: http://localhost:8000"
	@echo "Auto-reload enabled for live editing"
	@echo "Press Ctrl+C to stop"
	@mkdocs serve --config-file config/mkdocs.yml --livereload

docs-build:
	@echo "Building Documentation Site..."
	@echo "================================"
	@if ! command -v mkdocs >/dev/null 2>&1; then \
		echo "Installing MkDocs..."; \
		pip install mkdocs-material mkdocs-git-revision-date-localized-plugin pymdown-extensions; \
	fi
	@mkdocs build --clean --strict --config-file config/mkdocs.yml --site-dir site
	@echo "Documentation built in ./site directory"

docs-deploy:
	@echo "Deploying Documentation to GitHub Pages..."
	@echo "=============================================="
	@if ! command -v mkdocs >/dev/null 2>&1; then \
		echo "Installing MkDocs..."; \
		pip install mkdocs-material mkdocs-git-revision-date-localized-plugin pymdown-extensions; \
	fi
	@echo "WARNING: This will deploy to GitHub Pages"
	@read -p "Continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		mkdocs gh-deploy --clean --config-file config/mkdocs.yml; \
		echo "Documentation deployed!"; \
	else \
		echo "Deployment cancelled"; \
	fi

stop:
	@echo "Stopping Documentation Server..."
	@echo "================================="
	@lsof -ti:8000 | xargs kill -9 2>/dev/null && echo "Server stopped" || echo "No server running"

check:
	@echo "Health Check - DEMO3 Presentation"
	@echo "==================================="
	@echo "Python version:"
	@python3 --version
	@echo "Pip version:"
	@pip --version
	@echo "MkDocs version:"
	@mkdocs --version || echo "MkDocs not installed"
	@echo "Config validation:"
	@mkdocs build --config-file config/mkdocs.yml --site-dir /tmp/mkdocs-test --quiet && echo "✓ Config valid" || echo "✗ Config invalid"
	@rm -rf /tmp/mkdocs-test 2>/dev/null || true

clean:
	@echo "Cleaning Build Artifacts..."
	@echo "=============================="
	@echo "Removing Python cache files..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@echo "Removing documentation build..."
	@rm -rf site/ 2>/dev/null || true
	@echo "Cleanup completed!"
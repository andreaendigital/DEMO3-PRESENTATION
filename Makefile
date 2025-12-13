.PHONY: help setup docs docs-build docs-deploy clean

help:
@echo "í³š DEMO3 Presentation Documentation"
@echo "======================================"
@echo "Available commands:"
@echo "  setup       - íº€ Install all dependencies"
@echo "  docs        - í³– Start local documentation server"
@echo "  docs-build  - í³ Build static documentation"
@echo "  docs-deploy - íº€ Deploy to GitHub Pages"
@echo "  clean       - í·¹ Clean build artifacts"

setup:
@echo "í³¦ Setting up DEMO3 Presentation..."
@echo "===================================="
@echo "í´ Checking Python..."
@python3 --version || (echo "âŒ Python3 not found" && exit 1)
@echo "í´ Checking pip..."
@pip --version || (echo "âŒ pip not found" && exit 1)
@echo "íº€ Installing documentation dependencies..."
@pip install -e .[dev]
@echo "âœ… Setup complete! Try: make docs"

docs:
@echo "ï¿½ï¿½ Starting Documentation Development Server..."
@echo "=============================================="
@if ! command -v mkdocs >/dev/null 2>&1; then \
echo "í³¦ Installing MkDocs..."; \
pip install mkdocs-material mkdocs-git-revision-date-localized-plugin pymdown-extensions; \
fi
@echo "í¼ Documentation server: http://localhost:8000"
@echo "í´„ Auto-reload enabled for live editing"
@echo "Press Ctrl+C to stop"
@mkdocs serve --config-file config/mkdocs.yml

docs-build:
@echo "í³ Building Documentation Site..."
@echo "================================"
@if ! command -v mkdocs >/dev/null 2>&1; then \
echo "í³¦ Installing MkDocs..."; \
pip install mkdocs-material mkdocs-git-revision-date-localized-plugin pymdown-extensions; \
fi
@mkdocs build --clean --strict --config-file config/mkdocs.yml --site-dir site
@echo "âœ… Documentation built in ./site directory"

docs-deploy:
@echo "íº€ Deploying Documentation to GitHub Pages..."
@echo "=============================================="
@if ! command -v mkdocs >/dev/null 2>&1; then \
echo "í³¦ Installing MkDocs..."; \
pip install mkdocs-material mkdocs-git-revision-date-localized-plugin pymdown-extensions; \
fi
@echo "âš ï¸  This will deploy to GitHub Pages"
@read -p "Continue? [y/N]: " confirm; \
if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
mkdocs gh-deploy --clean --config-file config/mkdocs.yml; \
echo "âœ… Documentation deployed!"; \
else \
echo "í±‹ Deployment cancelled"; \
fi

clean:
@echo "ï¿½ï¿½ Cleaning Build Artifacts..."
@echo "=============================="
@echo "í·‘ï¸  Removing Python cache files..."
@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
@find . -name "*.pyc" -delete 2>/dev/null || true
@echo "í·‘ï¸  Removing documentation build..."
@rm -rf site/ 2>/dev/null || true
@echo "âœ… Cleanup completed!"

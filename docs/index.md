# DEMO3 Presentation

![Status](https://img.shields.io/badge/status-active-success.svg)
![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)

## ��� Bienvenido

Esta es la documentación profesional para **DEMO3 Presentation**. Un sitio de documentación moderno construido con MkDocs Material.

---

## ✨ Características Principales

!!! success "Material Design"
    Interfaz moderna y profesional con tema Material Design de Google

!!! info "GitHub Pages"
    Desplegado automáticamente en GitHub Pages con cada push a `main`

!!! tip "CI/CD Automático"
    Pipeline de GitHub Actions para deployment continuo

---

## ��� Inicio Rápido

### Requisitos Previos

- Python 3.9 o superior
- pip (gestor de paquetes de Python)
- Git

### Instalación Local

```bash
# Clonar el repositorio
git clone https://github.com/andreaendigital/DEMO3-PRESENTATION.git
cd DEMO3-PRESENTATION

# Instalar dependencias
make setup

# Iniciar servidor local
make docs
```

El sitio estará disponible en: [http://localhost:8000](http://localhost:8000)

---

## ��� Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `make setup` | Instala todas las dependencias necesarias |
| `make docs` | Inicia el servidor de desarrollo local |
| `make docs-build` | Construye el sitio estático |
| `make docs-deploy` | Despliega a GitHub Pages |
| `make clean` | Limpia archivos temporales |

---

## ���️ Stack Tecnológico

- **MkDocs Material** - Framework de documentación moderno
- **GitHub Actions** - CI/CD automático  
- **GitHub Pages** - Hosting gratuito
- **Pymdown Extensions** - Extensiones avanzadas de Markdown

---

## ��� Estructura del Proyecto

```plaintext
DEMO3-PRESENTATION/
├── docs/                    # Archivos de documentación
│   └── index.md            # Página principal
├── config/                  # Archivos de configuración
│   └── mkdocs.yml          # Configuración de MkDocs
├── .github/                 # GitHub configuration
│   └── workflows/          # GitHub Actions workflows
│       └── docs.yml        # Deploy automation
├── pyproject.toml          # Configuración del proyecto Python
├── Makefile                # Comandos de desarrollo
└── README.md               # Documentación del repositorio
```

---

## ��� Características del Tema

### Modo Claro/Oscuro

El sitio soporta automáticamente modo claro y oscuro según la preferencia del sistema o mediante el switch manual.

### Navegación Instantánea

- Carga instantánea de páginas sin recargar
- Búsqueda en tiempo real
- Seguimiento automático de scroll

---

## ��� Desarrollo

### Agregar Contenido

1. Crea archivos `.md` en la carpeta `docs/`
2. Actualiza la navegación en `config/mkdocs.yml`
3. Visualiza cambios con `make docs`
4. Commit y push para desplegar automáticamente

---

## ��� Deployment

### Automático (Recomendado)

Cada push a la rama `main` despliega automáticamente:

```bash
git add .
git commit -m "docs: update content"
git push origin main
```

### Manual

```bash
make docs-deploy
```

---

## ��� Estado del Proyecto

| Aspecto | Estado |
|---------|--------|
| Desarrollo | ✅ Activo |
| CI/CD | ✅ Configurado |
| GitHub Pages | ��� Pendiente |
| Documentación | ✅ Inicial |

---

## ��� Contacto

**Andrea** - [@andreaendigital](https://github.com/andreaendigital)

**Project Link:** [https://github.com/andreaendigital/DEMO3-PRESENTATION](https://github.com/andreaendigital/DEMO3-PRESENTATION)

---

<div align="center">

**Construido con ❤️ usando [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)**

</div>

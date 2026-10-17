# Fuentes oficiales consultadas · 2026-10-15
- https://www.docuseal.com/install
- https://github.com/docusealco/docuseal/tree/3.3.2
- https://github.com/docusealco/docuseal/blob/3.3.2/config/dotenv.rb
- https://github.com/docusealco/docuseal/blob/3.3.2/config/environments/production.rb
- https://github.com/docusealco/docuseal/blob/3.3.2/config/database.yml
- https://github.com/docusealco/docuseal/blob/3.3.2/config/initializers/migrate.rb
- https://github.com/docusealco/docuseal/blob/3.3.2/lib/puma/plugin/redis_server.rb
- https://github.com/docusealco/docuseal/blob/3.3.2/LICENSE_ADDITIONAL_TERMS
- https://hub.docker.com/v2/repositories/docuseal/docuseal/tags/3.3.2

App y Mailpit fijados por digest. postgres:17-alpine es herramienta auxiliar con etiqueta de versión mayor; resolver y fijar digest en el entorno de Hefesto antes de congelar release operativo.

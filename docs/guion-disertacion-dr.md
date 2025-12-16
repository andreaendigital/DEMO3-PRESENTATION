# Guión de Disertación: Disaster Recovery Multi-Cloud

## Introducción (2-3 minutos)

Buenos días. Hoy voy a presentarles un sistema de disaster recovery que desarrollamos para garantizar la continuidad operacional de nuestro servicio Git corporativo Gitea, implementado mediante una arquitectura multi-cloud entre AWS y Azure.

El desafío que enfrentamos era claro: ¿Cómo garantizamos que nuestro servicio de control de versiones crítico permanezca disponible incluso ante una caída completa de la región primaria de AWS? La respuesta nos llevó a diseñar una arquitectura de alta disponibilidad con un objetivo de tiempo de recuperación de 20 minutos y una pérdida de datos inferior a 1 segundo.

Permítanme guiarlos a través de tres aspectos fundamentales: primero, cómo construimos la infraestructura de replicación; segundo, cómo detectamos y respondemos ante una caída; y tercero, cómo ejecutamos el proceso de recuperación.

---

## Parte 1: Construcción de la Infraestructura de Replicación (5-7 minutos)

### La Arquitectura Base

Nuestra arquitectura se fundamenta en el principio de redundancia geográfica. Tenemos dos regiones cloud completamente independientes: AWS us-east-1 como sitio primario y Azure East US como sitio de disaster recovery. Pero aquí está la innovación: no mantenemos una réplica completa activa en Azure. Eso sería prohibitivamente costoso. En su lugar, implementamos lo que llamamos una arquitectura "cost-optimized standby".

En operación normal, Azure solamente mantiene activa la base de datos MySQL en modo réplica, consumiendo aproximadamente 25 dólares mensuales. No hay máquinas virtuales. No hay balanceadores de carga. Solo los datos, manteniéndose sincronizados en tiempo real. Esto reduce nuestros costos operacionales del disaster recovery en un 75% comparado con una réplica activa-activa tradicional.

### El Túnel VPN: La Columna Vertebral de la Replicación

Para que los datos fluyan entre AWS y Azure, necesitábamos un canal de comunicación seguro y confiable. Aquí es donde entra el concepto de VPN Site-to-Site con IPsec. Este no es un simple túnel VPN como el que usarías en tu laptop. Es una conexión permanente de nivel empresarial que establece un enlace cifrado entre dos Virtual Private Clouds en diferentes proveedores.

La implementación técnica requirió varios componentes críticos. Primero, en AWS desplegamos un Virtual Private Gateway, que actúa como el punto de terminación del túnel desde el lado de AWS. Este gateway se conecta a nuestra VPC donde reside el RDS MySQL. En Azure, implementamos un Virtual Network Gateway de tipo VPN, que cumple la función equivalente del lado de Azure.

La configuración de seguridad es donde la complejidad se manifiesta. Utilizamos el protocolo IKEv2 para el intercambio de claves, con cifrado AES-256 para el tráfico de datos y SHA-256 para la autenticación de integridad. Implementamos Perfect Forward Secrecy mediante Diffie-Hellman grupo 14, lo que significa que incluso si una clave de sesión se compromete, las sesiones anteriores permanecen seguras.

Pero hay un detalle arquitectónico crítico: configuramos el túnel en modo activo-pasivo con dos túneles redundantes. ¿Por qué dos? Porque los servicios cloud pueden reiniciar o hacer mantenimiento en el endpoint del túnel sin previo aviso. Con dos túneles, si uno cae, el otro mantiene la conectividad sin interrupción en la replicación de datos.

### Replicación MySQL: El Corazón del Sistema

Ahora, la replicación de base de datos es donde todo cobra vida. Implementamos MySQL 8.0 con replicación binlog asíncrona en formato ROW. Permítanme explicar por qué cada una de estas decisiones técnicas es importante.

El binlog o binary log es el mecanismo nativo de MySQL para capturar todos los cambios que ocurren en la base de datos. Cada INSERT, UPDATE, DELETE queda registrado en este log de manera secuencial. Pero hay diferentes formatos de binlog. Elegimos el formato ROW porque captura exactamente qué filas fueron modificadas y con qué valores. Esto es superior al formato STATEMENT, que solo registra el SQL ejecutado, porque el formato ROW garantiza consistencia incluso cuando hay funciones no determinísticas o diferencias de configuración entre servidores.

La replicación funciona con una arquitectura maestro-esclavo. El servidor en AWS es el maestro con server-id 1, configurado con log_bin habilitado para generar el binlog. El servidor en Azure es la réplica con server-id 2, configurado con relay_log para recibir y aplicar los cambios.

Aquí está lo fascinante del proceso técnico: en AWS configuramos un usuario específico de replicación con privilegios REPLICATION SLAVE. Este usuario se conecta desde Azure a través del túnel VPN cifrado. La réplica de Azure mantiene dos threads críticos: el IO thread que lee los eventos del binlog del maestro y los escribe en el relay log local, y el SQL thread que lee del relay log y ejecuta las transacciones en la base de datos local.

El lag de replicación, ese delta de tiempo entre cuando ocurre un cambio en AWS y cuando se aplica en Azure, es típicamente menor a 1 segundo. Esto lo logramos mediante varios factores: el ancho de banda dedicado del túnel VPN, la baja latencia entre regiones de AWS y Azure en la costa este, y la configuración de semi-sync replication en operaciones críticas.

Pero hay un aspecto operacional importante: durante la operación normal, la base de datos de Azure está en modo read-only para prevenir cualquier escritura accidental que rompería la replicación. Sin embargo, y esto es crucial para el failover, Azure MySQL Flexible Server no está realmente en modo read-only estricto. Puede convertirse en maestro simplemente deteniendo la replicación, sin necesidad de cambios de configuración adicionales.

---

## Parte 2: Detección de Caídas y Activación de Alertas (3-4 minutos)

### Monitoreo Multi-Capa

La detección temprana de fallos es fundamental para cumplir nuestro objetivo de RTO de 20 minutos. Implementamos un sistema de monitoreo en tres capas que opera bajo el principio de "defense in depth".

La primera capa es el health check del Application Load Balancer de AWS. Cada 30 segundos, el ALB envía una petición HTTP al endpoint de salud de Gitea. Si tres intentos consecutivos fallan, el ALB marca el target como unhealthy. Pero aquí está el problema: si falla toda la región de AWS, el ALB mismo está caído, por lo que no puede alertarnos.

La segunda capa es CloudWatch con métricas sintéticas. Tenemos un Lambda function que se ejecuta cada minuto desde una región diferente de AWS, intentando acceder al servicio. Esta Lambda está en us-west-2, geográficamente separada de nuestra producción en us-east-1. Si detecta fallo, CloudWatch Alarm se dispara inmediatamente.

La tercera capa, y quizás la más crítica, es el monitoreo externo mediante UptimeRobot o similar. Este servicio SaaS monitorea desde múltiples ubicaciones geográficas globales, completamente fuera de AWS. Es nuestra última línea de defensa para detectar una caída regional completa.

### Cascada de Notificaciones

Cuando se detecta una caída potencial, se activa una cascada de notificaciones diseñada para escalar apropiadamente. El primer nivel son notificaciones automatizadas por Slack al canal de incident-response. Estas notificaciones incluyen el timestamp exacto, el tipo de fallo detectado, y enlaces directos a los dashboards relevantes.

Simultáneamente, se envían emails al equipo de guardia. Pero no solo un email genérico. El sistema envía un análisis preliminar: si solo el ALB health check falló pero CloudWatch desde otra región responde, probablemente es un problema de aplicación, no de región. Si ambos fallan, es probable un problema de región.

El tercer nivel, si no hay respuesta humana en 5 minutos, es una llamada telefónica automatizada. Esto puede parecer antiguo, pero en el caos de un incidente mayor donde múltiples sistemas pueden estar alertando, una llamada telefónica corta el ruido.

### Análisis y Decisión

Lo crucial aquí es entender que no todo fallo amerita un failover a Azure. El failover es una operación costosa y compleja que cambia fundamentalmente dónde está nuestra fuente de verdad de datos. Por eso, el equipo de guardia debe ejecutar un análisis rápido de 2 minutos para confirmar:

¿Es realmente una caída de región o solo un problema de aplicación? Verificamos AWS Service Health Dashboard. Si AWS reporta problemas regionales en us-east-1, especialmente en EC2 o RDS, eso confirma la hipótesis.

¿Está Azure funcionando correctamente? Verificamos que la réplica de MySQL en Azure está respondiendo y que su replication lag es normal. No tiene sentido hacer failover a un sitio que también tiene problemas.

¿Cuál es el impacto en negocio? Si es 3 AM y hay cero usuarios conectados, podríamos esperar 30 minutos para ver si AWS se recupera. Si es medio día con 500 desarrolladores intentando hacer push de código, el failover es inmediato.

---

## Parte 3: Ejecución del Recovery (5-7 minutos)

### Fase de Deployment: Jenkins como Orquestador

Una vez tomada la decisión de hacer failover, el proceso de recovery se ejecuta mediante Jenkins, nuestra plataforma de CI/CD que actúa como orquestador central. Este detalle es fundamental: no ejecutamos scripts manualmente. Todo está codificado en un Jenkinsfile que garantiza consistencia y auditabilidad.

El operador de guardia accede al Jenkins master, navega al pipeline llamado "Azure-Gitea-Deployment" y lo dispara con parámetros específicos. Los parámetros son críticos aquí. Configuramos DEPLOYMENT_MODE en FAILOVER, no FULL_STACK. Esta distinción le dice a Jenkins que la base de datos ya existe y no debe intentar crearla.

Establecemos PLAN_TERRAFORM en true, APPLY_TERRAFORM en true, y DEPLOY_ANSIBLE en true. Esta combinación significa: primero verifica qué va a crear Terraform, luego créalo, y finalmente configura la aplicación con Ansible.

### Terraform: Infraestructura como Código

Cuando Jenkins ejecuta Terraform, está materializando infraestructura descrita como código en archivos HCL. En aproximadamente 7 a 10 minutos, Terraform crea varios recursos en Azure:

Primero, una máquina virtual Standard_B2s con 2 vCPUs y 4 GB de RAM, suficiente para correr Gitea con carga moderada. Esta VM se despliega en la subnet privada donde ya existe nuestra base de datos MySQL.

Segundo, un Azure Load Balancer de tipo Standard, que será el nuevo punto de entrada público para los usuarios. El load balancer recibe una IP pública estática que eventualmente reemplazará el DNS del servicio.

Tercero, interfaces de red, security groups configurados para permitir tráfico SSH desde rangos específicos y tráfico HTTP/HTTPS desde internet, y discos managed con cifrado habilitado por defecto.

Lo elegante de Terraform aquí es que todo es idempotente. Si el pipeline falla a mitad de camino y necesitamos re-ejecutarlo, Terraform entiende qué recursos ya existen y solo crea lo faltante. Esto es crucial en un escenario de alta presión.

Al finalizar, Terraform genera outputs: la IP privada de la VM, la IP pública del load balancer, y otros datos que necesitamos para la siguiente fase.

### Ansible: Configuración Automatizada

Con la infraestructura creada, Jenkins automáticamente procede a la fase de configuración con Ansible. Este es un momento crítico: tenemos máquinas virtuales vacías que necesitan convertirse en servidores funcionales de Gitea en menos de 5 minutos.

Jenkins toma los outputs de Terraform y genera dinámicamente un archivo de inventario de Ansible. Este inventario especifica las IPs de las máquinas target y las credenciales SSH necesarias. Aquí encontramos un desafío técnico interesante: la VM de Gitea está en subnet privada sin IP pública directa. Ansible necesita conectarse a través de un jump host o bastion.

La solución que implementamos es ProxyJump en la configuración SSH de Ansible. Le decimos a Ansible: para conectarte a la VM de Gitea en 10.1.2.x, primero SSH al bastion en la IP pública, y desde ahí salta a la VM privada. Esto se logra con un simple parámetro ansible_ssh_common_args.

El playbook de Ansible ejecuta varias tareas secuenciales. Primero, instala dependencias del sistema: git, build-essential, y otras herramientas. Luego descarga el binario precompilado de Gitea versión 1.21.5 desde el repositorio oficial de GitHub.

La configuración crítica está en el archivo app.ini de Gitea. Ansible usa un template Jinja2 que inserta variables específicas del ambiente de Azure. La sección de base de datos es particularmente importante: especificamos el hostname del MySQL de Azure, el puerto 3306, y las credenciales. Utilizamos Ansible Vault para cifrar estas credenciales en el repositorio Git.

Ansible también configura Gitea como un systemd service, asegurando que se inicie automáticamente si la VM se reinicia. Habilita el servicio, lo inicia, y luego ejecuta una verificación de salud simple: intenta hacer un HTTP GET al localhost:3000 para confirmar que Gitea responde.

### Promoción de Base de Datos: El Momento Crítico

Con la aplicación desplegada, llegamos al paso más delicado del failover: promover la réplica de MySQL a maestro. Este es un momento de no-retorno. Una vez que hacemos esto, Azure MySQL deja de ser réplica y se convierte en la fuente autoritativa de datos.

El operador se conecta vía SSH a la VM de Gitea o utiliza un cliente MySQL directo para conectarse al MySQL Flexible Server de Azure. Ejecuta dos comandos SQL simples pero poderosos: STOP REPLICA para detener los threads de replicación, y RESET REPLICA ALL para eliminar completamente la configuración de replicación y las coordenadas del binlog del maestro antiguo.

Es importante entender que Azure MySQL Flexible Server, a diferencia de implementaciones tradicionales de réplicas, no está en modo read_only estricto. Esto significa que no necesitamos ejecutar comandos adicionales para hacerlo escribible. Simplemente dejamos de replicar y automáticamente puede aceptar escrituras.

Verificamos con SHOW MASTER STATUS que la base de datos ahora está generando su propio binlog. Esto es importante porque si algún día queremos hacer failback a AWS, necesitamos este binlog para sincronizar datos en dirección inversa.

### Validación y Activación

Los últimos minutos del proceso son de validación exhaustiva antes de declarar el recovery exitoso. Primero, verificamos que Gitea está accesible a través de la IP del load balancer de Azure. Hacemos un git clone de un repositorio de prueba para confirmar que las operaciones de lectura funcionan.

Luego, ejecutamos una operación de escritura: creamos un nuevo repositorio de prueba o hacemos un push de un commit. Esto confirma que la base de datos está aceptando escrituras y que la integración entre Gitea y MySQL funciona correctamente.

Finalmente, actualizamos el DNS. Si estamos usando AWS Route 53 o cualquier otro proveedor de DNS, cambiamos el registro A de gitea.company.com para que apunte a la nueva IP pública del load balancer de Azure en lugar del ALB de AWS. Este cambio de DNS puede tomar de 5 a 60 minutos en propagarse globalmente, dependiendo de nuestros TTL configurados.

Durante esta ventana de propagación de DNS, tendremos usuarios llegando tanto al sitio viejo (AWS caído) como al nuevo (Azure funcionando). Los que lleguen a AWS verán errores. Los que lleguen a Azure verán el servicio funcionando. Es un período incómodo pero inevitable.

---

## Conclusión (2 minutos)

Lo que hemos construido aquí es más que un simple sistema de backup. Es una arquitectura completa de disaster recovery que balancea tres objetivos críticos: disponibilidad, costo y complejidad operacional.

Nuestro RTO de 20 minutos está compuesto de 6 minutos de detección, 2 minutos de decisión, 15 minutos de deployment automatizado, y unos minutos finales de validación. Este timeline es realista y alcanzable porque hemos automatizado cada paso que es automatizable y hemos practicado los pasos manuales hasta que son segunda naturaleza.

Nuestro RPO de menos de 1 segundo es posible gracias a la replicación continua de MySQL a través del túnel VPN cifrado. En el peor caso de un failover, perdemos solo las transacciones que estaban en vuelo en el momento exacto de la caída.

El costo de mantener esta capacidad es de aproximadamente 125 dólares mensuales: 100 dólares en AWS para la operación normal, y 25 dólares en Azure solo para la réplica de base de datos. Cuando ocurre un failover, el costo de Azure sube a 100 dólares por los recursos adicionales, pero AWS baja a cero, manteniendo el costo total controlado.

La lección técnica más importante que quiero dejar es esta: el disaster recovery efectivo no es solo sobre tener backups. Es sobre tener un proceso completo, probado y automatizado para convertir esos backups en sistemas funcionando bajo presión. Es sobre tomar decisiones arquitectónicas deliberadas como la réplica cost-optimized, implementar capas de monitoreo redundantes, y sobre todo, documentar y practicar el proceso hasta que el equipo pueda ejecutarlo casi instintivamente en medio de una crisis.

Gracias por su atención. Estoy disponible para preguntas.

---

_Este guión está diseñado para una presentación de 20-25 minutos. Ajuste el ritmo según el tiempo disponible y el nivel técnico de la audiencia._

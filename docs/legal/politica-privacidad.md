> **BORRADOR — revisar con abogado antes de publicar. Última actualización: 2026-06-25.**

---

# Política de Privacidad — Pregúntale a tu Plata

## 1. Responsable del tratamiento

El responsable del tratamiento de tus datos personales es:

- **Nombre / Razón social:** [NOMBRE COMPLETO DEL TITULAR O RAZÓN SOCIAL]
- **RUT:** [RUT]
- **Domicilio:** [DIRECCIÓN, COMUNA, CIUDAD, CHILE]
- **Correo de privacidad:** privacidad@[DOMINIO].cl

Para cualquier consulta relacionada con tus datos personales, puedes escribirnos a la dirección de correo indicada.

---

## 2. Qué datos recopilamos

Recopilamos únicamente los datos necesarios para prestarte el servicio:

| Categoría | Detalle |
|-----------|---------|
| **Cuenta** | Correo electrónico y contraseña (almacenada con hash). |
| **Archivos subidos por ti** | Cartolas bancarias en formato PDF o CSV, y fotografías de boletas o comprobantes que tú mismo cargas en la app. No accedemos a tu banco de forma directa. |
| **Datos de uso** | Registros técnicos (logs) de las sesiones: fecha/hora de acceso, tipo de consulta, errores. No vendemos ni usamos estos logs con fines publicitarios. |
| **Datos de pago** | El procesamiento del pago es realizado íntegramente por la pasarela de pago [NOMBRE PASARELA, ej. Stripe / Flow]. Nosotros no almacenamos número de tarjeta ni datos bancarios completos. |

---

## 3. Para qué usamos tus datos (finalidades)

Usamos tus datos exclusivamente para:

1. **Prestarte el servicio:** analizar los archivos que subas y permitirte conversar con la IA sobre tus propios gastos e ingresos.
2. **Gestionar tu cuenta y suscripción:** crear tu perfil, procesar el cobro mensual y enviarte notificaciones relacionadas al servicio.
3. **Mejorar el servicio:** analizar de forma agregada y anónima patrones de uso para corregir errores y mejorar funciones.
4. **Cumplir obligaciones legales:** responder a requerimientos de autoridades competentes cuando la ley lo exija.

**No usamos tus datos para publicidad de terceros.**

---

## 4. Base de licitud

El tratamiento de tus datos se basa en:

- **Consentimiento:** al registrarte y aceptar esta política, consientes el tratamiento de tus datos para las finalidades descritas. Puedes revocar tu consentimiento en cualquier momento (ver sección 9).
- **Ejecución del contrato:** parte del tratamiento es necesaria para prestarte el servicio que contrataste (términos y condiciones).
- **Obligación legal:** cuando la ley chilena nos exige conservar o entregar información.

---

## 5. Transferencia internacional de datos

Para prestarte el servicio, parte del procesamiento se realiza fuera de Chile:

- **OpenAI (EE.UU.):** Los textos derivados de tus archivos son enviados a los servidores de OpenAI para ser analizados por modelos de inteligencia artificial (actualmente GPT-4o mini). Este proveedor está sujeto a sus propios [Términos de Servicio y Política de Privacidad](https://openai.com/policies/privacy-policy).
- **Supabase:** La base de datos y el almacenamiento de archivos están alojados en Supabase, con servidores en [REGIÓN, ej. AWS us-east-1].

**Medidas de protección:** Antes de enviar cualquier texto a la IA, enmascaramos automáticamente los RUT y números de cuenta bancaria detectados en los documentos (reemplazados por marcadores como `[RUT]` y `[CUENTA]`). Aun así, los archivos pueden contener otro tipo de información financiera personal.

**No compartimos tus datos con terceros para fines publicitarios, de marketing o de venta de datos.**

---

## 6. Minimización y seudonimización

Aplicamos el principio de minimización: solo tratamos los datos estrictamente necesarios. En particular:

- Los RUT y números de cuenta son enmascarados antes de enviarse al modelo de IA.
- Los archivos subidos se almacenan de forma cifrada y solo son accesibles por tu cuenta.

---

## 7. Retención y eliminación de datos

| Dato | Plazo de retención |
|------|--------------------|
| Archivos subidos (cartolas, fotos) e historial financiero | Se conservan mientras uses la app y hasta **1 año después de tu última sesión activa** — necesitamos tu historial para darte comparativos y análisis útiles. Puedes eliminarlos de inmediato cuando lo solicites desde la app. |
| Datos de cuenta (email, historial de conversaciones) | Se conservan mientras tu cuenta esté activa. Al eliminar tu cuenta, se borran en un plazo máximo de **30 días hábiles**. |
| Logs técnicos | Se conservan por un máximo de **12 meses** con fines de seguridad y diagnóstico, luego se eliminan. |
| Datos de facturación | Se conservan por el plazo que exija la legislación tributaria chilena (actualmente 6 años). |

Puedes eliminar tus datos en cualquier momento desde **Ajustes → Eliminar mis datos** dentro de la app, sin necesidad de contactarnos.

---

## 8. Seguridad

Aplicamos las siguientes medidas técnicas para proteger tu información:

- **Cifrado en tránsito:** todas las comunicaciones entre la app y nuestros servidores usan TLS 1.2 o superior.
- **Cifrado en reposo:** los archivos almacenados en Supabase están cifrados en reposo (AES-256).
- **Acceso mínimo:** solo el sistema automatizado accede a tus archivos para procesarlos; ningún empleado accede a tus cartolas de forma rutinaria.
- **Autenticación:** usamos tokens JWT con firma RS256 para autenticar sesiones.

Sin perjuicio de lo anterior, ningún sistema es 100% seguro. En caso de una brecha de seguridad que afecte tus datos, te notificaremos dentro de los plazos que exija la ley.

---

## 9. Tus derechos (ARCO y otros)

De acuerdo con la **Ley 19.628** (vigente) y la **Ley 21.719** (que amplía los derechos desde el 1 de diciembre de 2026), tienes los siguientes derechos respecto de tus datos:

| Derecho | Qué significa |
|---------|---------------|
| **Acceso** | Solicitar qué datos tuyos tenemos y cómo los usamos. |
| **Rectificación** | Pedirnos que corrijamos datos incorrectos o incompletos. |
| **Cancelación / Supresión** | Solicitar que eliminemos tus datos cuando ya no sean necesarios o hayas revocado el consentimiento. |
| **Oposición** | Oponerte a ciertos tratamientos (por ejemplo, análisis agregados). |
| **Portabilidad** *(desde Ley 21.719)* | Recibir tus datos en un formato estructurado y legible por máquina, y solicitar su transferencia a otro proveedor. |
| **Decisiones automatizadas** *(desde Ley 21.719)* | No ser objeto de decisiones que te afecten significativamente basadas únicamente en tratamiento automatizado, sin revisión humana. |

**Cómo ejercer tus derechos:**

1. **Desde la app:** usa el botón **"Eliminar mis datos"** en Ajustes (para supresión total).
2. **Por correo:** escribe a privacidad@[DOMINIO].cl indicando: tu nombre completo, el derecho que deseas ejercer y una descripción de tu solicitud.
3. **Plazo de respuesta:** responderemos dentro de los **15 días hábiles** siguientes a la recepción de tu solicitud. Si la complejidad lo requiere, podemos extender el plazo otros 15 días hábiles, informándote de ello.

Si consideras que hemos vulnerado tus derechos, puedes presentar un reclamo ante el **Consejo para la Transparencia** (actual autoridad de control en materia de datos personales) o ante la autoridad que corresponda una vez que la Ley 21.719 entre en plena vigencia.

---

## 10. Menores de edad

Este servicio está **prohibido para personas menores de 14 años**. Al registrarte, declaras tener 14 años o más. Si tomamos conocimiento de que hemos recopilado datos de un menor de 14 años sin consentimiento del titular de la patria potestad, eliminaremos la cuenta y los datos asociados de inmediato.

---

## 11. Marco legal aplicable

Esta política se rige por:

- **Ley 19.628** sobre protección de la vida privada (vigente).
- **Ley 21.719** que reemplaza y amplía la protección de datos personales (vigencia: **1 de diciembre de 2026**). Desde esa fecha, este documento será actualizado para reflejar los nuevos requisitos.

---

## 12. Cambios a esta política

Si modificamos esta política, te notificaremos con al menos **30 días de anticipación** por correo electrónico o mediante aviso en la app. Si los cambios son sustanciales y no los aceptas, podrás cancelar tu cuenta sin penalidad antes de la fecha de entrada en vigencia.

---

## 13. Contacto

**Correo de privacidad:** privacidad@[DOMINIO].cl
**Plazo de respuesta:** 15 días hábiles

---

*Este documento es un borrador de referencia. Debe ser revisado y validado por un abogado especialista en protección de datos antes de su publicación.*

"""
Categorización de transacciones: reglas por comercios chilenos + normalización de salida LLM.
"""
import unicodedata
import re

CATEGORIAS = [
    "Comida y delivery",
    "Supermercado",
    "Transporte",
    "Cuentas y servicios",
    "Suscripciones",
    "Salud",
    "Entretención",
    "Compras",
    "Efectivo",
    "Transferencias",
    "Otros",
]

# ---------------------------------------------------------------------------
# Mapa de keywords → categoría. Cada entrada es (pattern, categoría).
# Se usa re.search (case-insensitive, accent-stripped).
# ---------------------------------------------------------------------------
_REGLAS: list[tuple[str, str]] = [
    # ---- Transferencias (antes que Efectivo para evitar false positives) ----
    (r"transf[ae]r|traspaso|abono a|pago a tercero|pago conta|cte a", "Transferencias"),

    # ---- Efectivo ----
    (r"giro|cajero|atm|avance|retiro efectivo|retiro caja", "Efectivo"),

    # ---- Comida y delivery ----
    (r"rappi|uber eats|ubereats|pedidosya|pedidos ya|justo\.cl|justo app|didi food|"
     r"mcdonald|mc donald|burger king|burgerking|kfc|kentucky|domino|pizza hut|"
     r"papa john|taco bell|starbucks|sushi|ceviche|parrilla|sandwich|lomito|empanada|"
     r"restaurant|restoran|pizzer|cafeter|fuente de soda|bar\b|bistro|"
     r"delivery|deliveroo|just eat|cornershop|uber eat", "Comida y delivery"),

    # ---- Supermercado ----
    (r"lider|l[íi]der|jumbo|santa isabel|tottus|unimarc|acuenta|ekono|"
     r"mayorista 10|mayorista10|big john|central mayorista|kas|fresh market|"
     r"\bmarket\b|supermercado|super mercado|almacen|\bminimarket\b|\bmini market\b", "Supermercado"),

    # ---- Transporte ----
    (r"uber\b|cabify|didi\b|beat\b|metro de santiago|bip\b|bip !|red movilidad|"
     r"copec|shell|petrobras|aramco|esso|bencina|combustible|gasolina|"
     r"peaje|autopista|vias chile|ruta\b|autoexpres|autovias|"
     r"latam|jetsmart|sky airline|sky air|turbus|pullman|tur bus|"
     r"transantiago|buses|tren central|ferrocarril|taxi|cabina|transfer\b", "Transporte"),

    # ---- Cuentas y servicios ----
    (r"enel|cge\b|aguas andinas|esval|essbio|aguas|metrogas|lipigas|gasco|"
     r"entel|movistar|wom\b|claro\b|vtr\b|gtd\b|mundo\b|telefon|internet|"
     r"elect|gas\b|agua\b|cuenta de servicio|servicio basico|"
     r"correos de chile|chilexpress|starken|blueexpress|blue express", "Cuentas y servicios"),

    # ---- Suscripciones ----
    (r"netflix|spotify|disney|hbo\b|max\b|prime video|amazon prime|youtube premium|"
     r"apple\b|icloud|google one|google storage|openai|chatgpt|canva\b|"
     r"dropbox|adobe|microsoft 365|office 365|xbox live|xbox game|playstation now|"
     r"ps plus|nintendo|twitch|patreon|onlyfans|paramount|crunchyroll|"
     r"deezer|tidal|pandora|audible|kindle|suscripci", "Suscripciones"),

    # ---- Salud ----
    (r"farmacia|farmacias|cruz verde|cruzver|salcobrand|ahumada|farmavalue|"
     r"clinica|cl[íi]nica|hospital|isapre|fonasa|dental|dentist|"
     r"optica|opticas|laboratorio|examen|consulta medica|consulta m[eé]d|"
     r"medic|doctor|dr\.|enferm|vacun|emergencia|urgencia|sanatorio", "Salud"),

    # ---- Entretención ----
    (r"cine|cinemark|cineplanet|hoyts|cinehoyts|cinestar|"
     r"steam\b|playstation store|ps store|xbox store|nintendo eshop|"
     r"passline|puntoticket|ticket|concierto|show\b|espect[aá]culo|"
     r"casino|apuesta|bingo|bowling|karting|escape room|museo|teatro|"
     r"parque|zoologico|acuario|entretenimiento", "Entretención"),

    # ---- Compras ----
    (r"falabella|paris\b|ripley|hites|la polar|lapolar|"
     r"mercado libre|mercadolibre|aliexpress|amazon\b|shein|temu\b|"
     r"sodimac|easy\b|homecenter|construmart|"
     r"pc factory|pcfactory|abcdin|electro\b|samsung|apple store|"
     r"linio|zara\b|h&m|forever 21|adidas|nike\b|forus|bata\b|"
     r"compra online|tienda online|e-commerce|ecommerce|"
     r"ikea|rex\b|paris cencosud|topitop", "Compras"),
]

# Compilar patrones una sola vez
_COMPILED: list[tuple[re.Pattern, str]] = [
    (re.compile(pat, re.IGNORECASE), cat)
    for pat, cat in _REGLAS
]


def _strip_accents(s: str) -> str:
    """Elimina tildes para comparaciones accent-insensitive."""
    return "".join(
        c for c in unicodedata.normalize("NFD", s)
        if unicodedata.category(c) != "Mn"
    )


def comercio_key(descripcion: str) -> str:
    """Clave de comercio para overrides: sin tildes, sin dígitos/puntuación, espacios colapsados."""
    s = _strip_accents(descripcion).lower()
    s = re.sub(r"[^a-z\s]", " ", s)   # quita dígitos y puntuación
    s = re.sub(r"\s+", " ", s).strip()
    return s


def categorizar_por_reglas(descripcion: str) -> str | None:
    """
    Devuelve la categoría que corresponde al comercio en `descripcion`,
    aplicando el mapa de keywords para comercios chilenos.
    Retorna None si ninguna regla aplica.
    """
    texto = _strip_accents(descripcion)
    for pattern, categoria in _COMPILED:
        if pattern.search(texto):
            return categoria
    return None


# Mapa de normalización: variantes en minúsculas → canonical
_NORM_MAP: dict[str, str] = {
    _strip_accents(c.lower()): c
    for c in CATEGORIAS
}

# Alias adicionales que el LLM puede devolver
_ALIASES: dict[str, str] = {
    "comida": "Comida y delivery",
    "delivery": "Comida y delivery",
    "restaurante": "Comida y delivery",
    "restaurant": "Comida y delivery",
    "food": "Comida y delivery",
    "super": "Supermercado",
    "grocery": "Supermercado",
    "groceries": "Supermercado",
    "mercado": "Supermercado",
    "transport": "Transporte",
    "taxi": "Transporte",
    "combustible": "Transporte",
    "gasolina": "Transporte",
    "bencina": "Transporte",
    "cuentas": "Cuentas y servicios",
    "servicios": "Cuentas y servicios",
    "utilities": "Cuentas y servicios",
    "suscripcion": "Suscripciones",
    "subscripcion": "Suscripciones",
    "subscription": "Suscripciones",
    "streaming": "Suscripciones",
    "salud": "Salud",
    "health": "Salud",
    "farmacia": "Salud",
    "medico": "Salud",
    "entretencion": "Entretención",
    "entretenimiento": "Entretención",
    "entertainment": "Entretención",
    "ocio": "Entretención",
    "compra": "Compras",
    "shopping": "Compras",
    "tienda": "Compras",
    "efectivo": "Efectivo",
    "atm": "Efectivo",
    "cash": "Efectivo",
    "cajero": "Efectivo",
    "transferencia": "Transferencias",
    "transfer": "Transferencias",
    "traspaso": "Transferencias",
    "otros": "Otros",
    "other": "Otros",
    "sin categoria": "Otros",
    "sin categoría": "Otros",
    "unknown": "Otros",
    "desconocido": "Otros",
}


def normalizar(categoria: str | None) -> str | None:
    """
    Mapea un string producido por el LLM al ítem canónico más cercano en CATEGORIAS.
    Tolerante a mayúsculas/minúsculas y tildes.
    Retorna None si no puede mapear.
    """
    if categoria is None:
        return None
    key = _strip_accents(categoria.strip().lower())
    # Exact match (accent-insensitive)
    if key in _NORM_MAP:
        return _NORM_MAP[key]
    # Alias lookup
    if key in {_strip_accents(k): v for k, v in _ALIASES.items()}:
        return {_strip_accents(k): v for k, v in _ALIASES.items()}[key]
    # Prefix/substring: si la clave coincide con el comienzo de alguna categoría canónica
    for canon_key, canon_val in _NORM_MAP.items():
        if canon_key.startswith(key) or key.startswith(canon_key):
            return canon_val
    return None

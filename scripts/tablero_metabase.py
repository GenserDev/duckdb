import os
import sys

import requests

from consultas import cargar_consultas

URL = os.environ.get("MB_URL", "http://metabase:3000")
CORREO = os.environ["MB_EMAIL"]
CLAVE = os.environ["MB_PASSWORD"]
BASE_EN_METABASE = "/workspace/data/processed/taxis.duckdb"
NOMBRE_BD = "Taxis NYC (DuckDB)"
NOMBRE_TABLERO = "Lab 8 - Viajes de taxi NYC 2024-2026"

COLOR_TIPO = {"yellow": {"color": "#eda100", "title": "Amarillos"}, "green": {"color": "#008300", "title": "Verdes"}}
COLOR_ANIO = {"2024": {"color": "#2a78d6"}, "2025": {"color": "#eb6834"}, "2026": {"color": "#1baf7a"}}

q = {nombre: sql.rstrip(";") for nombre, sql in cargar_consultas("05_indicadores.sql").items()}


def filtrar(nombre, condicion):
    return f"SELECT * FROM ({q[nombre]}) AS t WHERE {condicion}"


def resumir(nombre, expresion, condicion="year(mes) = (SELECT max(year(mes)) FROM viajes_validos)"):
    return f"SELECT {expresion} AS valor FROM ({q[nombre]}) AS t WHERE {condicion}"


def linea(dimensiones, metricas, series=None, **extra):
    ajustes = {"graph.dimensions": dimensiones, "graph.metrics": metricas, "graph.x_axis.title_text": ""}
    if series:
        ajustes["series_settings"] = series
    ajustes.update(extra)
    return ajustes


TARJETAS = [
    ("KPI viajes por día 2026 (amarillos)", resumir("i1_viajes_por_dia", "round(avg(viajes_por_dia))", "year(mes) = 2026 AND tipo_taxi = 'yellow'"), "scalar", {}, (0, 0, 6, 3)),
    ("KPI participación de verdes 2026 (%)", resumir("i2_participacion_verdes", "round(avg(pct_verdes), 2)", "year(mes) = 2026"), "scalar", {}, (0, 6, 6, 3)),
    ("KPI total mediano 2026 amarillos (USD)", resumir("i3_total_mediano", "round(avg(total_mediano_usd), 2)", "year(mes) = 2026 AND tipo_taxi = 'yellow'"), "scalar", {}, (0, 12, 6, 3)),
    ("KPI viajes amarillos sin forma de pago 2026 (%)", resumir("i6_forma_de_pago", "round(avg(pct_sin_dato), 1)", "year(mes) = 2026"), "scalar", {}, (0, 18, 6, 3)),
    ("I1 Viajes por día, amarillos", filtrar("i1_viajes_por_dia", "tipo_taxi = 'yellow'"), "line", linea(["mes"], ["viajes_por_dia"], **{"graph.colors": ["#eda100"]}), (3, 0, 12, 6)),
    ("I1 Viajes por día, verdes", filtrar("i1_viajes_por_dia", "tipo_taxi = 'green'"), "line", linea(["mes"], ["viajes_por_dia"], **{"graph.colors": ["#008300"]}), (3, 12, 12, 6)),
    ("I2 Participación de taxis verdes (%)", q["i2_participacion_verdes"], "line", linea(["mes"], ["pct_verdes"], **{"graph.colors": ["#008300"]}), (9, 0, 12, 6)),
    ("I3 Monto total mediano (USD)", q["i3_total_mediano"], "line", linea(["mes", "tipo_taxi"], ["total_mediano_usd"], COLOR_TIPO), (9, 12, 12, 6)),
    ("I6 Forma de pago, amarillos (%)", q["i6_forma_de_pago"], "line", linea(["mes"], ["pct_tarjeta", "pct_efectivo", "pct_sin_dato"], **{"graph.colors": ["#2a78d6", "#1baf7a", "#e34948"]}), (15, 0, 12, 6)),
    ("I5 Propina mediana con tarjeta (% de la tarifa)", q["i5_propina_tarjeta"], "line", linea(["mes", "tipo_taxi"], ["propina_mediana_pct"], COLOR_TIPO), (15, 12, 12, 6)),
    ("I7 Velocidad mediana en Manhattan, días hábiles 7-19 h (mph)", q["i7_velocidad_manhattan"], "line", linea(["mes"], ["velocidad_mediana_mph"], **{"graph.colors": ["#4a3aa7"]}), (21, 0, 12, 6)),
    ("I9 Distribución de viajes por hora (%)", q["i9_viajes_por_hora"], "line", linea(["hora", "anio"], ["pct_viajes"], COLOR_ANIO), (21, 12, 12, 6)),
    ("I4 Composición del cobro (%)", q["i4_peso_de_recargos"], "table", {}, (27, 0, 12, 6)),
    ("I8 Viajes amarillos desde aeropuertos", q["i8_viajes_aeropuerto"], "table", {}, (27, 12, 12, 6)),
    ("I10 Zonas con más recogidas", q["i10_top_zonas"], "row", {"graph.dimensions": ["zona"], "graph.metrics": ["viajes_total"], "graph.colors": ["#2a78d6"]}, (33, 0, 12, 7)),
    ("I11 Registros válidos (%)", q["i11_registros_validos"], "line", linea(["mes", "tipo_taxi"], ["pct_validos"], COLOR_TIPO), (33, 12, 12, 7)),
]


def api(sesion, metodo, ruta, **kwargs):
    respuesta = sesion.request(metodo, f"{URL}/api{ruta}", timeout=600, **kwargs)
    if not respuesta.ok:
        sys.exit(f"{metodo} {ruta} -> {respuesta.status_code}: {respuesta.text[:500]}")
    return respuesta.json() if respuesta.content else None


def iniciar_sesion():
    sesion = requests.Session()
    propiedades = api(sesion, "GET", "/session/properties")
    if propiedades.get("setup-token"):
        api(sesion, "POST", "/setup", json={
            "token": propiedades["setup-token"],
            "user": {"email": CORREO, "password": CLAVE, "first_name": "Lab", "last_name": "8"},
            "prefs": {"site_name": "Lab 8 DuckDB", "site_locale": "es", "allow_tracking": False},
        })
    token = api(sesion, "POST", "/session", json={"username": CORREO, "password": CLAVE})["id"]
    sesion.headers["X-Metabase-Session"] = token
    return sesion


def obtener_base(sesion):
    # read_only evita bloquear el archivo y memory_limit evita que DuckDB tumbe el contenedor de Metabase
    detalles = {"database_file": BASE_EN_METABASE, "read_only": True, "memory_limit": "2GB"}
    for base in api(sesion, "GET", "/database")["data"]:
        if base["name"] == NOMBRE_BD:
            api(sesion, "PUT", f"/database/{base['id']}", json={"details": detalles})
            return base["id"]
    return api(sesion, "POST", "/database", json={"engine": "duckdb", "name": NOMBRE_BD, "details": detalles})["id"]


def limpiar_anteriores(sesion):
    nombres = {t[0] for t in TARJETAS}
    for tarjeta in api(sesion, "GET", "/card"):
        if tarjeta["name"] in nombres and not tarjeta["archived"]:
            api(sesion, "PUT", f"/card/{tarjeta['id']}", json={"archived": True})
    for tablero in api(sesion, "GET", "/dashboard"):
        if tablero["name"] == NOMBRE_TABLERO and not tablero.get("archived"):
            api(sesion, "PUT", f"/dashboard/{tablero['id']}", json={"archived": True})


def main():
    sesion = iniciar_sesion()
    id_base = obtener_base(sesion)
    limpiar_anteriores(sesion)

    tablero = api(sesion, "POST", "/dashboard", json={"name": NOMBRE_TABLERO, "width": "full"})
    tarjetas_tablero = []
    for posicion, (nombre, sql, tipo, ajustes, (fila, columna, ancho, alto)) in enumerate(TARJETAS, start=1):
        tarjeta = api(sesion, "POST", "/card", json={
            "name": nombre,
            "display": tipo,
            "visualization_settings": ajustes,
            "dataset_query": {"type": "native", "native": {"query": sql, "template-tags": {}}, "database": id_base},
        })
        tarjetas_tablero.append({"id": -posicion, "card_id": tarjeta["id"], "row": fila, "col": columna,
                                 "size_x": ancho, "size_y": alto})
        print(f"  tarjeta {tarjeta['id']}: {nombre}")

    api(sesion, "PUT", f"/dashboard/{tablero['id']}", json={"dashcards": tarjetas_tablero})
    api(sesion, "PUT", "/setting/enable-public-sharing", json={"value": True})
    publico = api(sesion, "POST", f"/dashboard/{tablero['id']}/public_link")["uuid"]
    print(f"\ntablero: http://localhost:3000/dashboard/{tablero['id']}")
    print(f"enlace publico: http://localhost:3000/public/dashboard/{publico}")


if __name__ == "__main__":
    main()

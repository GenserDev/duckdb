import os
import re
import time
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parent.parent
DIR_SQL = RAIZ / "sql"


def cargar_consultas(archivo):
    texto = (DIR_SQL / archivo).read_text()
    bloques = re.split(r"^-- name: *(\S+) *$", texto, flags=re.MULTILINE)
    return {nombre: sql.strip() for nombre, sql in zip(bloques[1::2], bloques[2::2])}


def conectar(base=":memory:", read_only=False, vistas=True):
    # Las rutas de los parquet son relativas a la raiz del proyecto
    os.chdir(RAIZ)
    con = duckdb.connect(str(base), read_only=read_only)
    if vistas:
        for sql in cargar_consultas("00_vistas.sql").values():
            con.execute(sql)
    return con


def ejecutar(con, consultas, nombre, mostrar_sql=True):
    sql = consultas[nombre]
    if mostrar_sql:
        print(sql, end="\n\n")
    inicio = time.perf_counter()
    resultado = con.sql(sql).df()
    print(f"[{nombre}] {len(resultado)} filas en {time.perf_counter() - inicio:.2f} s")
    return resultado

import statistics
import time

import duckdb
import pandas as pd

from consultas import RAIZ, cargar_consultas, conectar

BASE_BENCHMARK = RAIZ / "data" / "processed" / "benchmark.duckdb"
RESULTADOS = RAIZ / "docs" / "benchmark_resultados.csv"
REPETICIONES = 5

TAMANIOS = {
    "1 mes (2026-01)": "2026/*2026-01.parquet",
    "8 meses (2026)": "2026/*.parquet",
    "todos los anios": "*/*.parquet",
}


def crear_vistas(con, patron):
    for sql in cargar_consultas("00_vistas.sql").values():
        for tipo in ("yellow", "green"):
            sql = sql.replace(f"data/raw/{tipo}/*/*.parquet", f"data/raw/{tipo}/{patron}")
        con.execute(sql)


def medir(con, sql):
    con.execute(sql).fetchall()
    tiempos = []
    for _ in range(REPETICIONES):
        inicio = time.perf_counter()
        con.execute(sql).fetchall()
        tiempos.append(time.perf_counter() - inicio)
    return statistics.median(tiempos)


def main():
    conectar(vistas=False)
    BASE_BENCHMARK.unlink(missing_ok=True)
    consultas = cargar_consultas("04_benchmark.sql")
    filas = []
    for etiqueta, patron in TAMANIOS.items():
        con = duckdb.connect()
        crear_vistas(con, patron)
        con.execute(f"ATTACH '{BASE_BENCHMARK}' AS bd")
        tabla = "bd.viajes_" + str(len(filas))
        inicio = time.perf_counter()
        con.execute(f"CREATE TABLE {tabla} AS SELECT * EXCLUDE (filename) FROM viajes")
        carga = time.perf_counter() - inicio
        registros = con.execute(f"SELECT count(*) FROM {tabla}").fetchone()[0]
        print(f"\n{etiqueta}: {registros:,} registros, tabla creada en {carga:.1f} s")
        filas.append({"tamanio": etiqueta, "consulta": "(creacion de la tabla)", "registros": registros,
                      "parquet_s": None, "tabla_s": round(carga, 4)})
        for nombre, sql in consultas.items():
            parquet = medir(con, sql.format(fuente="viajes"))
            materializada = medir(con, sql.format(fuente=tabla))
            print(f"  {nombre:<24} parquet {parquet:7.3f} s   tabla {materializada:7.3f} s")
            filas.append({"tamanio": etiqueta, "consulta": nombre, "registros": registros,
                          "parquet_s": round(parquet, 4), "tabla_s": round(materializada, 4)})
        con.close()
    resultados = pd.DataFrame(filas)
    resultados["veces_mas_rapida_tabla"] = (resultados.parquet_s / resultados.tabla_s).round(1)
    resultados.to_csv(RESULTADOS, index=False)
    print(f"\nresultados -> {RESULTADOS}")


if __name__ == "__main__":
    main()

import sys
import time
from pathlib import Path

from consultas import RAIZ, cargar_consultas, conectar

BASE = RAIZ / "data" / "processed" / "taxis.duckdb"


def materializar(base=BASE):
    base.unlink(missing_ok=True)
    con = conectar()
    con.execute(f"ATTACH '{base}' AS bd")
    inicio = time.perf_counter()
    # filename se descarta porque anio_archivo y mes_archivo ya guardan lo necesario
    con.execute("CREATE TABLE bd.viajes AS SELECT * EXCLUDE (filename) FROM viajes")
    con.execute("CREATE TABLE bd.zonas AS SELECT * FROM zonas")
    segundos = time.perf_counter() - inicio
    filas = con.execute("SELECT count(*) FROM bd.viajes").fetchone()[0]
    con.close()
    # La vista se crea dentro de la base para que Metabase use el mismo SQL de sql/05_indicadores.sql
    con = conectar(base, vistas=False)
    con.execute(cargar_consultas("00_vistas.sql")["vista_viajes_validos"])
    con.close()
    print(f"{filas:,} viajes materializados en {segundos:.1f} s -> {base} ({base.stat().st_size / 2**20:,.0f} MiB)")
    return segundos


if __name__ == "__main__":
    materializar(Path(sys.argv[1]) if len(sys.argv) > 1 else BASE)

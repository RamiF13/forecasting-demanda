
import pandas as pd

from db import crear_engine

def cargar_mart():
    """Lee la tabla mart_training_dataset y la devuelve como DataFrame de pandas"""
    engine = crear_engine()
    consulta = "SELECT * FROM marts.mart_training_dataset"
    return pd.read_sql(consulta, engine)
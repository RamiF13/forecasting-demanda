
import os 

from dotenv import load_dotenv
from sqlalchemy import create_engine

def crear_engine():
    """Crea un engine de SQLAlchemy con las credenciales del .env"""
    load_dotenv()

    config = {
            "DB_HOST": os.getenv("DB_HOST"),
            "DB_PORT": os.getenv("DB_PORT"),
            "DB_USER": os.getenv("DB_USER"),
            "DB_PASSWORD": os.getenv("DB_PASSWORD"),
            "DB_NAME": os.getenv("DB_NAME"),
        }

    faltantes = [nombre for nombre, valor in config.items() if not valor]
    if faltantes:
        raise ValueError(f"Faltan variables en el .env: {faltantes}")

    return create_engine(
        f"postgresql+psycopg2://{config['DB_USER']}:{config['DB_PASSWORD']}"
        f"@{config['DB_HOST']}:{config['DB_PORT']}/{config['DB_NAME']}"
    )